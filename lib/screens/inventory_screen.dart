import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../core/permissions/permissions.dart';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';
import '../core/utils/perf_logger.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/premium/premium_card.dart';
import '../widgets/ai_design_system.dart';
import 'add_product_screen.dart';
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
    PerfLogger.logPageOpen('Inventory');
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfLogger.logFirstRender('Inventory');
    });
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
    await _productRepository.deleteProduct(product.businessId, product.id);
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      body: StreamBuilder<List<ProductModel>>(
        stream: _productRepository.watchProducts(
          BusinessContext.businessId,
        ),
        builder: (context, snapshot) {
          final hasData = snapshot.hasData && snapshot.data != null;
          final products = snapshot.data ?? const <ProductModel>[];
          final filteredProducts = _filterProducts(products);

          // Calculate summary metrics
          final totalCount = products.length;
          final lowStockCount = products.where((p) => p.isLowStock && !p.isOutOfStock).length;
          final outOfStockCount = products.where((p) => p.isOutOfStock).length;

          return Column(
            children: [
              // Page Header
              AiPageHeader(
                title: copy.isEnglish ? 'Inventory & Stock' : 'المخزون والمشتريات',
                subtitle: copy.isEnglish 
                    ? 'Track quantities, unit costs, and profit margins.'
                    : 'إدارة المخزون والتكلفة والربحية وتقييم الأصول المالية.',
                actions: const [SyncStatusIndicator()],
              ),

              // Scrollable Cockpit Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: AppTheme.aiCard,
                  color: AppTheme.aiGold,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Summary Cards Row
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isDesktop ? 3 : 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isDesktop ? 2.5 : 1.5,
                        children: [
                          AiKpiCard(
                            label: copy.isEnglish ? 'Total Items' : 'إجمالي الأصناف',
                            value: '$totalCount',
                            icon: Icons.inventory_2_rounded,
                            accentColor: AppTheme.aiBlue,
                          ),
                          AiKpiCard(
                            label: copy.isEnglish ? 'Low Stock' : 'مخزون منخفض',
                            value: '$lowStockCount',
                            icon: Icons.warning_amber_rounded,
                            accentColor: AppTheme.aiGold,
                          ),
                          AiKpiCard(
                            label: copy.isEnglish ? 'Out of Stock' : 'نفد من المخزون',
                            value: '$outOfStockCount',
                            icon: Icons.remove_shopping_cart_rounded,
                            accentColor: AppTheme.aiRed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Search & Filter Panel
                      PremiumCard(
                        padding: const EdgeInsets.all(20),
                        border: Border.all(
                          color: AppTheme.aiGold.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        child: Column(
                          children: [
                            AiSearchField(
                              controller: _searchController,
                              hintText: copy.isEnglish ? 'Search inventory...' : 'ابحث باسم الصنف أو الباركود...',
                              onClear: _searchController.clear,
                            ),
                            const SizedBox(height: 16),
                            if (isDesktop)
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<InventoryFilter>(
                                      initialValue: _selectedFilter,
                                      dropdownColor: AppTheme.aiCardElevated,
                                      style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        labelText: copy.isEnglish ? 'Stock Filter' : 'تصفية المخزون',
                                        filled: true,
                                        fillColor: AppTheme.aiCardElevated,
                                      ),
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
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<InventorySort>(
                                      initialValue: _selectedSort,
                                      dropdownColor: AppTheme.aiCardElevated,
                                      style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        labelText: copy.isEnglish ? 'Sort By' : 'ترتيب حسب',
                                        filled: true,
                                        fillColor: AppTheme.aiCardElevated,
                                      ),
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
                                  ),
                                ],
                              )
                            else ...[
                              DropdownButtonFormField<InventoryFilter>(
                                initialValue: _selectedFilter,
                                dropdownColor: AppTheme.aiCardElevated,
                                style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: copy.isEnglish ? 'Stock Filter' : 'تصفية المخزون',
                                  filled: true,
                                  fillColor: AppTheme.aiCardElevated,
                                ),
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
                                dropdownColor: AppTheme.aiCardElevated,
                                style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: copy.isEnglish ? 'Sort By' : 'ترتيب حسب',
                                  filled: true,
                                  fillColor: AppTheme.aiCardElevated,
                                ),
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
                            ],
                            const SizedBox(height: 10),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _sortAscending,
                              title: Text(
                                copy.isEnglish ? 'Ascending Order' : 'ترتيب تصاعدي',
                                style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              onChanged: (value) =>
                                  setState(() => _sortAscending = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            copy.inventoryResultCount(filteredProducts.length),
                            style: const TextStyle(
                              color: AppTheme.aiGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          AiActionButton(
                            label: copy.isEnglish ? 'Add Item' : 'إضافة صنف',
                            icon: Icons.add_circle_rounded,
                            color: AppTheme.aiGold,
                            isSmall: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddProductScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Products content list / empty state
                      if (snapshot.hasError)
                        _buildErrorState(context, copy, snapshot.error)
                      else if (!hasData && snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator(color: AppTheme.aiGold))
                      else if (products.isEmpty)
                        _buildEmptyState(context, copy)
                      else if (filteredProducts.isEmpty)
                        AiGlassCard(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              copy.isEnglish ? 'No matching products found.' : 'لا توجد نتائج مطابقة لبحثك وتصفيتك.',
                              style: const TextStyle(color: AppTheme.aiTextSecondary, fontWeight: FontWeight.bold),
                            ),
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
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppCopy copy, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.aiRed, size: 48),
            const SizedBox(height: 16),
            Text(
              copy.isEnglish ? 'Error loading inventory' : 'فشل تحميل بيانات المخزون من الخادم المحلي.',
              style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w800, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(copy.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppCopy copy) {
    return PremiumCard(
      border: Border.all(
        color: AppTheme.aiGold.withValues(alpha: 0.15),
        width: 1,
      ),
      child: Column(
        children: [
          AiEmptyState(
            icon: Icons.inventory_2_rounded,
            title: copy.isEnglish ? 'No products in inventory yet' : 'لا توجد أصناف في المخزون بعد',
            subtitle: copy.isEnglish 
                ? 'Start by adding your first product to manage costs, pricing, and profitability.'
                : 'أضف أول صنف لبدء إدارة المخزون، وحساب التكلفة والربحية وتقييم الأصول.',
            action: AiActionButton(
              label: copy.isEnglish ? 'Add Product' : 'أضف أول صنف الآن',
              icon: Icons.add_circle_outline_rounded,
              color: AppTheme.aiGold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.aiGold.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.aiGold.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, color: AppTheme.aiGold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    copy.isEnglish 
                        ? 'AI Hint: You can sync products from the cloud sync center instantly.'
                        : 'تلميح ذكي: يمكنك استيراد ومزامنة أصنافك المسجلة سحابياً مباشرة من مركز المزامنة.',
                    style: const TextStyle(
                      color: AppTheme.aiGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(ProductModel product, AppCopy copy) {
    final badge = _statusBadge(product, copy);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      border: Border.all(
        color: product.isOutOfStock 
            ? AppTheme.aiRed.withValues(alpha: 0.2)
            : (product.isLowStock 
                ? AppTheme.aiGold.withValues(alpha: 0.2) 
                : AppTheme.aiGreen.withValues(alpha: 0.2)),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (product.isOutOfStock 
                      ? AppTheme.aiRed 
                      : (product.isLowStock ? AppTheme.aiGold : AppTheme.aiGreen)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: product.isOutOfStock 
                        ? AppTheme.aiRed 
                        : (product.isLowStock ? AppTheme.aiGold : AppTheme.aiGreen),
                  ),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: product.isOutOfStock 
                      ? AppTheme.aiRed
                      : (product.isLowStock ? AppTheme.aiGold : AppTheme.aiGreen),
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
                        color: AppTheme.aiTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.inventoryUnitLine(product.unit),
                      style: const TextStyle(
                        color: AppTheme.aiTextSecondary,
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
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AiActionButton(
                label: copy.t('quickSell'),
                icon: Icons.sell_rounded,
                color: AppTheme.aiGold,
                isSmall: true,
                onTap: product.isOutOfStock
                    ? () {}
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellProductScreen(product: product),
                          ),
                        );
                      },
              ),
              AiSecondaryButton(
                label: copy.t('details'),
                icon: Icons.info_outlined,
                isSmall: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsScreen(product: product),
                    ),
                  );
                },
              ),
              if (AppPermissions.canEditProducts(BusinessContext.role))
                AiSecondaryButton(
                  label: copy.t('edit'),
                  icon: Icons.edit_outlined,
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProductScreen(product: product),
                      ),
                    );
                  },
                ),
              if (AppPermissions.canDelete(BusinessContext.role))
                AiSecondaryButton(
                  label: copy.t('delete'),
                  icon: Icons.delete_outlined,
                  isSmall: true,
                  onTap: () => _confirmDelete(product),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.aiCardBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _statusBadge(ProductModel product, AppCopy copy) {
    late final Color color;
    late final String text;

    if (product.isOutOfStock) {
      color = AppTheme.aiRed;
      text = copy.t('outOfStock');
    } else if (product.isLowStock) {
      color = AppTheme.aiGold;
      text = copy.t('lowStock');
    } else {
      color = AppTheme.aiGreen;
      text = copy.t('stable');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10),
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