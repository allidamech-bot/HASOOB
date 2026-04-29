import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_theme.dart';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';
import '../widgets/app_section_header.dart';
import 'inventory_adjustment_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});
  final ProductModel product;
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  late ProductModel _product; late Future<Map<String, dynamic>> _dataFuture;
  @override void initState(){super.initState(); _product=widget.product; _dataFuture=_loadData();}
  Future<Map<String,dynamic>> _loadData() async { final results=await Future.wait<dynamic>([_productRepository.getProductSalesCount(_product.id),_productRepository.getProductSoldQty(_product.id),_productRepository.getProductRealizedProfit(_product.id),_productRepository.getProductRealizedSales(_product.id),_productRepository.getProductSalesHistory(_product.id),_productRepository.getProductMovementHistory(_product.id)]); return {'salesCount':results[0] as int,'soldQty':results[1] as int,'realizedProfit':results[2] as double,'realizedSales':results[3] as double,'salesHistory':results[4] as List<Map<String,dynamic>>,'movementHistory':results[5] as List<Map<String,dynamic>>}; }
  Future<void> _refresh() async { final refreshed=await _productRepository.getProductById(_product.id); if(!mounted)return; setState((){ if(refreshed!=null)_product=refreshed; _dataFuture=_loadData();}); await _dataFuture; }
  Future<void> _openAdjustment() async { final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>InventoryAdjustmentScreen(product:_product))); if(changed==true) await _refresh(); }

  @override Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('productDetails')),
        actions: [IconButton(onPressed: _openAdjustment, tooltip: copy.t('adjustment'), icon: const Icon(Icons.tune_rounded))],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 36),
                        const SizedBox(height: 12),
                        Text(copy.t('loadProductDetailsError'), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryFor(context))),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _refresh, child: Text(copy.t('retry'))),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data!; final salesCount = _toInt(data['salesCount']); final soldQty = _toInt(data['soldQty']); final realizedProfit = _toDouble(data['realizedProfit']); final realizedSales = _toDouble(data['realizedSales']); final salesHistory = data['salesHistory'] as List<Map<String, dynamic>>; final movementHistory = data['movementHistory'] as List<Map<String, dynamic>>;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_rounded, size: 42, color: AppTheme.accent),
                        const SizedBox(height: 8),
                        Text(_product.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(copy.productDetailsUnitLine(_product.unit), style: TextStyle(color: AppTheme.textSecondaryFor(context))),
                        const SizedBox(height: 12),
                        _statusBadge(_product, copy),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(onPressed: _openAdjustment, icon: const Icon(Icons.tune_rounded), label: Text(copy.t('adjustStockOrCost'))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppSectionHeader(title: copy.t('pricingAndStock'), subtitle: copy.t('pricingAndStockSubtitle')),
                const SizedBox(height: 10),
                _infoCard(copy.t('purchasePrice'), AppFormatters.currency(_product.purchasePrice)),
                _infoCard(copy.t('extraCosts'), AppFormatters.currency(_product.extraCosts)),
                _infoCard(copy.t('landedCost'), AppFormatters.currency(_product.landedCost)),
                _infoCard(copy.t('sellingPrice'), AppFormatters.currency(_product.sellingPrice)),
                _infoCard(copy.t('unitProfit'), AppFormatters.currency(_product.netProfit), valueColor: _product.netProfit >= 0 ? AppTheme.success : AppTheme.danger),
                _infoCard(copy.t('currentQuantity'), AppFormatters.number(_product.stockQty), valueColor: _product.isOutOfStock ? AppTheme.danger : _product.isLowStock ? AppTheme.warning : AppTheme.success),
                _infoCard(copy.t('lowStockThreshold'), AppFormatters.number(_product.lowStockThreshold)),
                if ((_product.barcode ?? '').isNotEmpty) _infoCard(copy.t('barcode'), _product.barcode!),
                const SizedBox(height: 16),
                AppSectionHeader(title: copy.t('salesPerformance'), subtitle: copy.t('salesPerformanceSubtitle')),
                const SizedBox(height: 10),
                _infoCard(copy.t('salesCount'), AppFormatters.number(salesCount)),
                _infoCard(copy.t('soldQuantity'), AppFormatters.number(soldQty)),
                _infoCard(copy.t('realizedSales'), AppFormatters.currency(realizedSales)),
                _infoCard(copy.t('realizedProfit'), AppFormatters.currency(realizedProfit), valueColor: realizedProfit >= 0 ? AppTheme.success : AppTheme.danger),
                const SizedBox(height: 16),
                AppSectionHeader(title: copy.t('stockMovements'), subtitle: copy.t('stockMovementsSubtitle')),
                const SizedBox(height: 10),
                if (movementHistory.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(copy.t('noStockMovements')))) else ...movementHistory.take(10).map((e) => _movementCard(e, copy)),
                const SizedBox(height: 16),
                AppSectionHeader(title: copy.t('latestSales'), subtitle: copy.t('latestSalesSubtitle')),
                const SizedBox(height: 10),
                if (salesHistory.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(copy.t('noProductSales')))) else ...salesHistory.take(10).map((e) => _saleCard(e, copy)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(String label, String value, {Color? valueColor}) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: AppTheme.textSecondaryFor(context), fontWeight: FontWeight.w600))), Text(value, style: TextStyle(color: valueColor ?? Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800))])));

  Widget _saleCard(Map<String, dynamic> row, AppCopy copy) {
    final qty = _toInt(row['qty']); final totalSale = _toDouble(row['total_sale']); final totalProfit = _toDouble(row['total_profit']); final customerName = row['customer_name']?.toString().trim(); final date = row['date']?.toString().trim() ?? '';
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: AppTheme.info.withValues(alpha: 0.15), child: const Icon(Icons.sell_rounded, color: AppTheme.info)), title: Text(copy.productDetailsQuantityLine(qty), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text([if (customerName != null && customerName.isNotEmpty) copy.productDetailsCustomerLine(customerName), if (date.isNotEmpty) date].join('\n')), isThreeLine: customerName != null && customerName.isNotEmpty, trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(AppFormatters.currency(totalSale), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(AppFormatters.currency(totalProfit), style: TextStyle(color: totalProfit >= 0 ? AppTheme.success : AppTheme.danger, fontWeight: FontWeight.w700, fontSize: 12))])));
  }

  Widget _movementCard(Map<String, dynamic> row, AppCopy copy) {
    final movementType = row['movement_type']?.toString() ?? ''; final quantity = _toInt(row['quantity']); final balanceAfter = _toInt(row['balance_after']); final notes = row['notes']?.toString().trim() ?? ''; final date = row['date']?.toString().trim() ?? ''; final isNegative = quantity < 0; final color = isNegative ? AppTheme.danger : AppTheme.success; final icon = isNegative ? Icons.remove_circle_outline : Icons.add_circle_outline;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(icon, color: color)), title: Text(_movementTypeLabel(movementType, copy), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text([copy.productDetailsQuantityLine(quantity), copy.productDetailsMovementBalanceLine(balanceAfter), if (notes.isNotEmpty) notes, if (date.isNotEmpty) date].join('\n'))));
  }

  Widget _statusBadge(ProductModel product, AppCopy copy) {
    late final Color color; late final String text;
    if (product.isOutOfStock) { color = AppTheme.danger; text = copy.t('outOfStock'); } else if (product.isLowStock) { color = AppTheme.warning; text = copy.t('lowStock'); } else { color = AppTheme.success; text = copy.t('stable'); }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2)), child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800)));
  }

  String _movementTypeLabel(String type, AppCopy copy) {
    switch (type) {
      case 'opening': return copy.t('openingBalance');
      case 'sale': return copy.t('sale');
      case 'invoice': return copy.t('invoice');
      case 'adjustment': return copy.t('adjustment');
      case 'cost_adjustment': return copy.t('costAdjustment');
      case 'restore': return copy.t('restore');
      default: return type.isEmpty ? copy.t('movement') : type;
    }
  }

  int _toInt(dynamic value) { if (value == null) return 0; if (value is num) return value.toInt(); return int.tryParse(value.toString()) ?? 0; }
  double _toDouble(dynamic value) { if (value == null) return 0; if (value is num) return value.toDouble(); return double.tryParse(value.toString()) ?? 0; }
}
