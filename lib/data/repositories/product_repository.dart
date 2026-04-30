import '../../data/database/database_helper.dart';
import '../models/product_model.dart';
import '../services/cloud_sync_service.dart';

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
  Stream<List<ProductModel>> watchProducts(String businessId) {
    return CloudSyncService.instance.watchProducts(businessId).map(
          (rows) => rows.map(ProductModel.fromMap).toList(),
        );
  }

  Future<List<ProductModel>> getAllProducts(String businessId) async {
    final data = await DBHelper.getProducts(businessId);
    return data.map((e) => ProductModel.fromMap(e)).toList();
  }

  Future<ProductModel?> getProductById(String businessId, String id) async {
    final data = await DBHelper.getProductById(businessId, id);
    if (data == null) return null;
    return ProductModel.fromMap(data);
  }

  Future<void> addProduct(String businessId, ProductModel product) async {
    await DBHelper.insertProduct(product.copyWith(businessId: businessId).toMap());
  }

  Future<void> updateProduct(String businessId, ProductModel product) async {
    await DBHelper.updateProduct(product.copyWith(businessId: businessId).toMap());
  }

  Future<void> deleteProduct(String businessId, String id) async {
    await DBHelper.deleteProduct(businessId, id);
  }

  Future<DeleteProductCheckResult> canDeleteProduct(ProductModel product) async {
    final salesCount = await DBHelper.getProductSalesCount(product.businessId, product.id);
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

  Future<List<Map<String, dynamic>>> getProductSalesHistory(String businessId, String productId) {
    return DBHelper.getProductSalesHistory(businessId, productId);
  }

  Future<List<Map<String, dynamic>>> getProductMovementHistory(
    String businessId,
    String productId,
  ) {
    return DBHelper.getProductMovementHistory(businessId, productId);
  }

  Future<List<Map<String, dynamic>>> getSalesRecords(String businessId) {
    return DBHelper.getSalesRecords(businessId);
  }

  Stream<List<Map<String, dynamic>>> watchSalesRecords(String businessId) {
    return CloudSyncService.instance.watchSalesRecords(businessId);
  }
}
