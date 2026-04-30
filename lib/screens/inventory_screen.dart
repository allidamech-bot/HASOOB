import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../core/permissions/permissions.dart';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';
import 'edit_product_screen.dart';
import 'product_details_screen.dart';
import 'sell_product_screen.dart';

enum InventoryFilter { all, lowStock, outOfStock, profitable, loss }

enum InventorySort { name, stockQty, unitProfit, sellingPrice }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductRepository _productRepository = ProductRepository();

  InventoryFilter _selectedFilter = InventoryFilter.all;
  InventorySort _selectedSort = InventorySort.name;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final businessId = BusinessContext.businessId;
    await _productRepository.getAllProducts(businessId);
  }

  Future<void> _delete(ProductModel product) async {
    await _productRepository.deleteProduct(product.id, product.businessId);
    if (!mounted) return;
    AppMessages.success(context, AppCopy.of(context).t('productDeleted'));
  }

  Future<void> _confirmDelete(ProductModel product) async {
    final copy = AppCopy.of(context);
    final result = await _productRepository.canDeleteProduct(product);
    if (!result.canDelete) {
      if (!mounted) return;
      AppMessages.error(
        context,
        result.message ?? copy.t('cannotDeleteProduct'),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.t('deleteProduct')),
        content: Text(copy.inventoryDeleteConfirm(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.t('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _delete(product);
    }
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    final query = _searchController.text.trim().toLowerCase();
    final result = products.where((product) {
      final barcode = (product.barcode ?? '').toLowerCase();
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.unit.toLowerCase().contains(query) ||
          barcode.contains(query);
      if (!matchesSearch) return false;
      switch (_selectedFilter) {
        case InventoryFilter.all:
          return true;
        case InventoryFilter.lowStock:
          return product.isLowStock && !product.isOutOfStock;
        case InventoryFilter.outOfStock:
          return product.isOutOfStock;
        case InventoryFilter.profitable:
          return product.netProfit > 0;
        case InventoryFilter.loss:
          return product.netProfit < 0;
      }
    }).toList();

    result.sort((a, b) {
      int comparison;
      switch (_selectedSort) {
        case InventorySort.name:
          comparison = a.name.compareTo(b.name);
          break;
        case InventorySort.stockQty:
          comparison = a.stockQty.compareTo(b.stockQty);
          break;
        case InventorySort.unitProfit:
          comparison = a.netProfit.compareTo(b.netProfit);
          break;
        case InventorySort.sellingPrice:
          comparison = a.sellingPrice.compareTo(b.sellingPrice);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.t('inventoryTitle'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<ProductModel>>(
          stream: _productRepository.watchProducts(
            BusinessContext.businessId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }

            final products = snapshot.data ?? const <ProductModel>[];
            final filteredProducts = _filterProducts(products);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: copy.t('searchInventoryHint'),
                    helperText: copy.t('searchInventoryHelp'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<InventoryFilter>(
                          initialValue: _selectedFilter,
                          decoration: InputDecoration(labelText: copy.t('productFilter')),
                          items: InventoryFilter.values
                              .map(
                                (filter) => DropdownMenuItem(
                                  value: filter,
                                  child: Text(_filterLabel(filter, copy)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedFilter = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<InventorySort>(
                          initialValue: _selectedSort,
                          decoration: InputDecoration(labelText: copy.t('sortBy')),
                          items: InventorySort.values
                              .map(
                                (sort) => DropdownMenuItem(
                                  value: sort,
                                  child: Text(_sortLabel(sort, copy)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedSort = value);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _sortAscending,
                          title: Text(copy.t('ascendingSort')),
                          onChanged: (value) =>
                              setState(() => _sortAscending = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.inventoryResultCount(filteredProducts.length),
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredProducts.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(copy.t('noMatchingProducts'))),
                    ),
                  )
                else
                  ...filteredProducts.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _productCard(product, copy),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _productCard(ProductModel product, AppCopy copy) {
    final badge = _statusBadge(product, copy);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy.inventoryUnitLine(product.unit),
                        style: TextStyle(
                          color: AppTheme.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                badge,
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(copy.t('stock'), '${product.stockQty}'),
                _infoChip(copy.t('minimumLimit'), '${product.lowStockThreshold}'),
                _infoChip(copy.t('sellingPrice'), AppFormatters.currency(product.sellingPrice)),
                _infoChip(copy.t('unitProfit'), AppFormatters.currency(product.netProfit)),
                if ((product.barcode ?? '').isNotEmpty)
                  _infoChip(copy.t('barcode'), product.barcode!),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: product.isOutOfStock
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellProductScreen(product: product),
                            ),
                          );
                        },
                  icon: const Icon(Icons.sell_rounded),
                  label: Text(copy.t('quickSell')),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsScreen(product: product),
                      ),
                    );
                  },
                  child: Text(copy.t('details')),
                ),
                OutlinedButton(
                  onPressed: !AppPermissions.canEditProducts(
                          BusinessContext.role)
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProductScreen(product: product),
                            ),
                          );
                        },
                  child: Text(copy.t('edit')),
                ),
                OutlinedButton(
                  onPressed: !AppPermissions.canDelete(
                          BusinessContext.role)
                      ? null
                      : () => _confirmDelete(product),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                  child: Text(copy.t('delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _statusBadge(ProductModel product, AppCopy copy) {
    late final Color color;
    late final String text;

    if (product.isOutOfStock) {
      color = AppTheme.danger;
      text = copy.t('outOfStock');
    } else if (product.isLowStock) {
      color = AppTheme.warning;
      text = copy.t('lowStock');
    } else {
      color = AppTheme.success;
      text = copy.t('stable');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _filterLabel(InventoryFilter filter, AppCopy copy) {
    switch (filter) {
      case InventoryFilter.all:
        return copy.t('all');
      case InventoryFilter.lowStock:
        return copy.t('lowStock');
      case InventoryFilter.outOfStock:
        return copy.t('outOfStock');
      case InventoryFilter.profitable:
        return copy.t('profitable');
      case InventoryFilter.loss:
        return copy.t('loss');
    }
  }

  String _sortLabel(InventorySort sort, AppCopy copy) {
    switch (sort) {
      case InventorySort.name:
        return copy.t('name');
      case InventorySort.stockQty:
        return copy.t('quantity');
      case InventorySort.unitProfit:
        return copy.t('unitProfit');
      case InventorySort.sellingPrice:
        return copy.t('sellingPrice');
    }
  }
}
