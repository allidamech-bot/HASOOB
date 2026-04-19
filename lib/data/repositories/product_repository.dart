import '../../data/database/database_helper.dart';
import '../../data/models/product.dart';
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
  Stream<List<Product>> watchProducts() {
    return CloudSyncService.instance.watchProducts().map(
          (rows) => rows.map(Product.fromMap).toList(),
        );
  }

  Future<List<Product>> getAllProducts() async {
    final data = await DBHelper.getProducts();
    return data.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final data = await DBHelper.getProductById(id);
    if (data == null) return null;
    return Product.fromMap(data);
  }

  Future<void> addProduct(Product product) async {
    await DBHelper.insertProduct(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await DBHelper.updateProduct(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await DBHelper.deleteProduct(id);
  }

  Future<DeleteProductCheckResult> canDeleteProduct(Product product) async {
    final salesCount = await DBHelper.getProductSalesCount(product.id);
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
    required String productId,
    required int qty,
    required double sellingPrice,
    String? customerName,
    String? saleNote,
    String? currencyCode,
  }) async {
    await DBHelper.sellProduct(
      productId: productId,
      qty: qty,
      sellingPrice: sellingPrice,
      customerName: customerName,
      saleNote: saleNote,
      currencyCode: currencyCode,
    );
  }

  Future<void> applyInventoryAdjustment({
    required String productId,
    int? newStockQty,
    double? newPurchasePrice,
    double? newExtraCosts,
    required String reason,
  }) async {
    await DBHelper.applyInventoryAdjustment(
      productId: productId,
      newStockQty: newStockQty,
      newPurchasePrice: newPurchasePrice,
      newExtraCosts: newExtraCosts,
      reason: reason,
    );
  }

  Future<int> getProductSalesCount(String productId) {
    return DBHelper.getProductSalesCount(productId);
  }

  Future<int> getProductSoldQty(String productId) {
    return DBHelper.getProductSoldQty(productId);
  }

  Future<double> getProductRealizedProfit(String productId) {
    return DBHelper.getProductRealizedProfit(productId);
  }

  Future<double> getProductRealizedSales(String productId) {
    return DBHelper.getProductRealizedSales(productId);
  }

  Future<List<Map<String, dynamic>>> getProductSalesHistory(String productId) {
    return DBHelper.getProductSalesHistory(productId);
  }

  Future<List<Map<String, dynamic>>> getProductMovementHistory(
    String productId,
  ) {
    return DBHelper.getProductMovementHistory(productId);
  }

  Future<List<Map<String, dynamic>>> getSalesRecords() {
    return DBHelper.getSalesRecords();
  }

  Stream<List<Map<String, dynamic>>> watchSalesRecords() {
    return CloudSyncService.instance.watchSalesRecords();
  }
}
