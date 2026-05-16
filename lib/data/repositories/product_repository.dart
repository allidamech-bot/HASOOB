import 'package:flutter/foundation.dart';
import '../../data/database/database_helper.dart';
import '../models/product_model.dart';
import 'package:hasoob_app/data/services/cloud_sync_service.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
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
  Stream<List<ProductModel>> watchProducts(String businessId) async* {
    // 1. Yield local data immediately as the source of truth
    final localData = await getAllProducts(businessId);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    // We treat cloud streams as optional triggers only.
    try {
      final cloudStream = CloudSyncService.instance.watchProducts(businessId);
      
      await for (final _ in cloudStream) {
        // Refresh from SQLite whenever cloud notifies of a change
        final refreshedData = await getAllProducts(businessId);
        yield refreshedData;
      }
      
      debugPrint('[ProductRepository] watchProducts cloud stream closed normally or after handled error.');
    } catch (e) {
      // This block is defensive; CloudSyncService now handles most errors internally.
      if (e.toString().contains('permission-denied')) {
        debugPrint('[ProductRepository] Cloud stream unavailable (permission-denied). Continuing in local-only mode.');
      } else {
        debugPrint('[ProductRepository] watchProducts cloud stream error: $e. Using local data only.');
      }
    }
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
  }

  Future<void> deleteProduct(String businessId, String id) async {
    await DBHelper.deleteProduct(businessId, id);

    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: id,
      type: SyncOperationType.delete,
      payload: {'id': id, 'businessId': businessId},
    );
  }

  Future<DeleteProductCheckResult> canDeleteProduct(
      ProductModel product) async {
    final salesCount =
        await DBHelper.getProductSalesCount(product.businessId, product.id);
    final hasStock = product.stockQty > 0;
    final hasSales = salesCount > 0;

    if (hasStock) {
      return const DeleteProductCheckResult(
        canDelete: false,
        hasSales: false,
        hasStock: true,
        message:
            'لا يمكن حذف الصنف طالما لديه رصيد مخزون. صفّر الرصيد أولًا عبر تدفق مناسب.',
      );
    }

    if (hasSales) {
      return const DeleteProductCheckResult(
        canDelete: false,
        hasSales: true,
        hasStock: false,
        message:
            'لا يمكن حذف الصنف لأنه مرتبط بسجل مبيعات، حفاظًا على سلامة التقارير والمحاسبة.',
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
    await DBHelper.sellProduct(
      businessId: businessId,
      productId: productId,
      qty: qty,
      sellingPrice: sellingPrice,
      customerName: customerName,
      saleNote: saleNote,
      currencyCode: currencyCode,
    );
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

  Stream<List<Map<String, dynamic>>> watchSalesRecords(
      String businessId) async* {
    // 1. Yield local data immediately
    final localData = await getSalesRecords(businessId);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    try {
      final cloudStream = CloudSyncService.instance.watchSalesRecords(businessId);
      
      await for (final _ in cloudStream) {
        final refreshedData = await getSalesRecords(businessId);
        yield refreshedData;
      }
      
      debugPrint('[ProductRepository] watchSalesRecords cloud stream closed.');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('[ProductRepository] watchSalesRecords cloud stream unavailable (permission-denied).');
      } else {
        debugPrint('[ProductRepository] watchSalesRecords cloud stream error: $e');
      }
    }
  }
}
