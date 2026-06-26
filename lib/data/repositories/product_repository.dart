import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/database/database_helper.dart';

import '../models/product_model.dart';
import 'package:hasoob_app/data/services/cloud_sync_service.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';

class DeleteProductCheckResult {
  final bool canDelete;
  final bool hasSales;
  final bool hasStock;
  final String? message;

  const DeleteProductCheckResult({
    required this.canDelete,
    required this.hasSales,
    required this.hasStock,
    this.message,
  });
}

class ProductRepository {
  static final ProductRepository instance = ProductRepository.internal();
  ProductRepository.internal();
  factory ProductRepository() => instance;

  @visibleForTesting
  ProductRepository.forTest();

  static CloudSyncService? _mockCloudSync;
  @visibleForTesting
  static set mockCloudSync(CloudSyncService? mock) => _mockCloudSync = mock;

  CloudSyncService get _cloudSync =>
      _mockCloudSync ?? CloudSyncService.instance;

  final _localChanges = StreamController<void>.broadcast();

  void _notifyChange() {
    debugPrint('[ProductRepository] Notifying local change');
    _localChanges.add(null);
  }

  Stream<List<ProductModel>> watchProducts(String businessId) {
    late StreamController<List<ProductModel>> controller;
    StreamSubscription? localSub;
    StreamSubscription? cloudSub;

    void emit() async {
      try {
        final data = await getAllProducts(businessId);
        if (!controller.isClosed) controller.add(data);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<ProductModel>>.broadcast(
      onListen: () {
        emit();
        localSub = _localChanges.stream.listen((_) => emit());
        cloudSub = _cloudSync.watchProducts(businessId).listen(
          (_) => emit(),
          onError: (e) {
            debugPrint('[ProductRepository] Cloud watch error: $e');
            if (e.toString().contains('permission-denied')) {
              SyncManager.instance.markCloudUnavailable(error: e.toString());
            }
          },
        );
      },
      onCancel: () {
        localSub?.cancel();
        cloudSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<List<ProductModel>> getAllProducts(String businessId) async {
    try {
      final data = await DBHelper.getProducts(businessId);
      return data.map((e) => ProductModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint(
          '[ProductRepository] Tolerating DB error on getAllProducts: $e');
      return [];
    }
  }

  Future<ProductModel?> getProductById(String businessId, String id) async {
    final data = await DBHelper.getProductById(businessId, id);
    if (data == null) return null;
    return ProductModel.fromMap(data);
  }

  Future<void> addProduct(String businessId, ProductModel product) async {
    debugPrint('[ProductRepository] addProduct started for ${product.id}');
    final productWithBusiness = product.copyWith(businessId: businessId);

    debugPrint('[ProductRepository] Inserting into local DB...');
    await DBHelper.insertProduct(productWithBusiness.toMap());
    debugPrint('[ProductRepository] Local DB insert successful');

    debugPrint('[ProductRepository] Enqueueing sync operation...');
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: productWithBusiness.id,
      type: SyncOperationType.create,
      payload: productWithBusiness.toMap(),
    );
    debugPrint('[ProductRepository] Sync enqueue successful');
    _notifyChange();
  }

  Future<void> updateProduct(String businessId, ProductModel product) async {
    final productWithBusiness = product.copyWith(businessId: businessId);
    await DBHelper.updateProduct(productWithBusiness.toMap());

    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: productWithBusiness.id,
      type: SyncOperationType.update,
      payload: productWithBusiness.toMap(),
    );
    _notifyChange();
  }

  Future<void> deleteProduct(String businessId, String id) async {
    final existing = await DBHelper.getProductById(businessId, id);
    if (existing == null) {
      throw StateError(
        'deleteProduct: product $id does not exist locally for business $businessId.',
      );
    }

    try {
      await DBHelper.deleteProduct(businessId, id);
    } catch (e) {
      if (e is Exception && e.toString().contains('لا يمكن حذف الصنف')) {
        rethrow;
      }
      debugPrint(
        '[ProductRepository] deleteProduct failed locally: '
        'businessId=$businessId, id=$id, error: $e',
      );
      throw StateError('تعذر حذف الصنف. قد يكون الصنف غير موجود.');
    }

    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: id,
      type: SyncOperationType.delete,
      payload: {'id': id, 'businessId': businessId},
    );
    _notifyChange();
  }

  Future<DeleteProductCheckResult> canDeleteProduct(
      ProductModel product) async {
    final db = await DBHelper.database();
    final salesCount =
        await DBHelper.getProductSalesCount(product.businessId, product.id);
    final hasStock = product.stockQty > 0;

    final hasInvoiceItems = await db.query(
      'invoice_items',
      where: 'product_id = ? AND businessId = ?',
      whereArgs: [product.id, product.businessId],
      limit: 1,
    );
    final hasQuotationItems = await db.query(
      'quotation_items',
      where: 'product_id = ? AND businessId = ?',
      whereArgs: [product.id, product.businessId],
      limit: 1,
    );

    if (hasStock) {
      return const DeleteProductCheckResult(
        canDelete: false,
        hasSales: false,
        hasStock: true,
        message:
            'لا يمكن حذف الصنف طالما لديه رصيد مخزون. صفّر الرصيد أولًا عبر تدفق مناسب.',
      );
    }

    if (salesCount > 0) {
      return const DeleteProductCheckResult(
        canDelete: false,
        hasSales: true,
        hasStock: false,
        message:
            'لا يمكن حذف الصنف لأنه مرتبط بسجلات مبيعات. حفاظًا على سلامة التقارير والمحاسبة.',
      );
    }

    if (hasInvoiceItems.isNotEmpty) {
      return const DeleteProductCheckResult(
        canDelete: false,
        hasSales: true,
        hasStock: false,
        message:
            'لا يمكن حذف الصنف لأنه مرتبط ببنود فواتير. احذف الفاتورة أولًا إذا رغب في حذف الصنف.',
      );
    }

    if (hasQuotationItems.isNotEmpty) {
      return const DeleteProductCheckResult(
        canDelete: false,
        hasSales: true,
        hasStock: false,
        message:
            'لا يمكن حذف الصنف لأنه مرتبط ببنود عروض أسعار. احذف عرض السعر أولًا إذا رغب في حذف الصنف.',
      );
    }

    return const DeleteProductCheckResult(
      canDelete: true,
      hasSales: false,
      hasStock: false,
      message: null,
    );
  }

  Future<void> sellProduct({
    required String businessId,
    required String productId,
    required int qty,
    required double sellingPrice,
    String? customerName,
    String? saleNote,
    String? currencyCode,
  }) async {
    final saleId = await DBHelper.sellProduct(
      businessId: businessId,
      productId: productId,
      qty: qty,
      sellingPrice: sellingPrice,
      customerName: customerName,
      saleNote: saleNote,
      currencyCode: currencyCode,
    );

    // Enqueue the sale record for sync
    final saleData = await DBHelper.getSalesRecords(businessId);
    final saleRecord = saleData.firstWhere((s) => s['id'] == saleId);

    await SyncQueueService.instance.enqueue(
      entityName: 'sales_records',
      entityId: saleId.toString(),
      type: SyncOperationType.create,
      payload: saleRecord,
    );

    // Enqueue the updated product state for sync
    final updatedProduct = await getProductById(businessId, productId);
    if (updatedProduct != null) {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: productId,
        type: SyncOperationType.update,
        payload: updatedProduct.toMap(),
      );
    }

    _notifyChange();
  }

  Future<void> applyInventoryAdjustment({
    required String businessId,
    required String productId,
    int? newStockQty,
    double? newPurchasePrice,
    double? newExtraCosts,
    required String reason,
  }) async {
    await DBHelper.applyInventoryAdjustment(
      businessId: businessId,
      productId: productId,
      newStockQty: newStockQty,
      newPurchasePrice: newPurchasePrice,
      newExtraCosts: newExtraCosts,
      reason: reason,
    );

    // Enqueue updated product state
    final updatedProduct = await getProductById(businessId, productId);
    if (updatedProduct != null) {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: productId,
        type: SyncOperationType.update,
        payload: updatedProduct.toMap(),
      );
    }

    _notifyChange();
  }

  Future<int> getProductSalesCount(String businessId, String productId) {
    return DBHelper.getProductSalesCount(businessId, productId);
  }

  Future<int> getProductSoldQty(String businessId, String productId) {
    return DBHelper.getProductSoldQty(businessId, productId);
  }

  Future<double> getProductRealizedProfit(String businessId, String productId) {
    return DBHelper.getProductRealizedProfit(businessId, productId);
  }

  Future<double> getProductRealizedSales(String businessId, String productId) {
    return DBHelper.getProductRealizedSales(businessId, productId);
  }

  Future<List<Map<String, dynamic>>> getProductSalesHistory(
      String businessId, String productId) {
    return DBHelper.getProductSalesHistory(businessId, productId);
  }

  Future<List<Map<String, dynamic>>> getProductMovementHistory(
    String businessId,
    String productId,
  ) {
    return DBHelper.getProductMovementHistory(businessId, productId);
  }

  Future<List<Map<String, dynamic>>> getSalesRecords(String businessId) async {
    try {
      return await DBHelper.getSalesRecords(businessId);
    } catch (e) {
      debugPrint(
          '[ProductRepository] Tolerating DB error on getSalesRecords: $e');
      return [];
    }
  }

  Future<double> getTotalInventoryValue(String businessId) {
    return DBHelper.getTotalInventoryValue(businessId);
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts(String businessId) {
    return DBHelper.getLowStockProducts(businessId);
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts(String businessId) {
    return DBHelper.getTopSellingProducts(businessId);
  }

  Stream<List<Map<String, dynamic>>> watchSalesRecords(String businessId) {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? localSub;
    StreamSubscription? cloudSub;

    void emit() async {
      try {
        final data = await getSalesRecords(businessId);
        if (!controller.isClosed) controller.add(data);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        emit();
        localSub = _localChanges.stream.listen((_) => emit());
        cloudSub = _cloudSync.watchSalesRecords(businessId).listen(
          (_) => emit(),
          onError: (e) {
            debugPrint('[ProductRepository] Sales cloud watch error: $e');
            if (e.toString().contains('permission-denied')) {
              SyncManager.instance.markCloudUnavailable(error: e.toString());
            }
          },
        );
      },
      onCancel: () {
        localSub?.cancel();
        cloudSub?.cancel();
      },
    );

    return controller.stream;
  }
}
