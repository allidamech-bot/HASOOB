import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../core/ui/responsive.dart';
import '../core/utils/perf_logger.dart';
import '../data/repositories/product_repository.dart';
import '../widgets/premium/premium_card.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/ai_design_system.dart';
import 'documents_screen.dart';
import 'inventory_screen.dart';
import 'collection_center_screen.dart' as collection;

enum SalesPeriodFilter { all, today, last7Days, last30Days }

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  SalesPeriodFilter _periodFilter = SalesPeriodFilter.all;
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    PerfLogger.logPageOpen('SalesHistory');
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfLogger.logFirstRender('SalesHistory');
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim().toLowerCase();
    if (nextQuery == _searchQuery) return;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || nextQuery == _searchQuery) return;
      setState(() {
        _searchQuery = nextQuery;
      });
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    final query = _searchQuery;
    final now = DateTime.now();

    return rows.where((row) {
      final productName = row['product_name']?.toString().toLowerCase() ?? '';
      final customerName = row['customer_name']?.toString().toLowerCase() ?? '';
      final matchesSearch = query.isEmpty ||
          productName.contains(query) ||
          customerName.contains(query);

      if (!matchesSearch) return false;

      final dateText = row['date']?.toString();
      DateTime? saleDate;
      if (dateText != null && dateText.isNotEmpty) {
        saleDate = DateTime.tryParse(dateText)?.toLocal();
      }

      switch (_periodFilter) {
        case SalesPeriodFilter.all:
          return true;
        case SalesPeriodFilter.today:
          return saleDate != null &&
              saleDate.year == now.year &&
              saleDate.month == now.month &&
              saleDate.day == now.day;
        case SalesPeriodFilter.last7Days:
          return saleDate != null &&
              !saleDate.isBefore(now.subtract(const Duration(days: 7)));
        case SalesPeriodFilter.last30Days:
          return saleDate != null &&
              !saleDate.isBefore(now.subtract(const Duration(days: 30)));
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isDesktop = UIResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _productRepository.watchSalesRecords(
          BusinessContext.businessId,
        ),
        builder: (context, snapshot) {
          final hasData = snapshot.hasData && snapshot.data != null;
          final originalRows = snapshot.data ?? const [];
          final filteredRows = _applyFilters(originalRows);

          final totalSalesVal = originalRows.fold<double>(
              0, (sum, item) => sum + _toDouble(item['total_sale']));
          final totalProfitVal = originalRows.fold<double>(
              0, (sum, item) => sum + _toDouble(item['total_profit']));
          final transactionCount = filteredRows.length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AiPageHeader(
                  title:
                      copy.isEnglish ? 'Sales & Invoices' : 'العملاء والفواتير',
                  subtitle: copy.isEnglish
                      ? 'Track sales operations, profit margins, and customer accounts.'
                      : 'تتبع المبيعات المباشرة، فواتير العملاء، الأرباح المحققة والمدفوعات.',
                  actions: const [SyncStatusIndicator()],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCollectionCenterCard(context, copy),
                      const SizedBox(height: 16),
                      // Summary KPI Cards
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isDesktop ? 3 : 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isDesktop ? 2.5 : 1.5,
                        children: [
                          AiKpiCard(
                            label: copy.isEnglish
                                ? 'Total Sales'
                                : 'إجمالي المبيعات',
                            value: AppFormatters.currency(totalSalesVal),
                            icon: Icons.payments_rounded,
                            accentColor: AppTheme.aiGold,
                          ),
                          AiKpiCard(
                            label: copy.isEnglish
                                ? 'Total Profit'
                                : 'صافي الأرباح',
                            value: AppFormatters.currency(totalProfitVal),
                            icon: Icons.trending_up_rounded,
                            accentColor: AppTheme.aiGreen,
                          ),
                          AiKpiCard(
                            label: copy.isEnglish
                                ? 'Filtered Txns'
                                : 'العمليات المصفاة',
                            value: '$transactionCount',
                            icon: Icons.point_of_sale_rounded,
                            accentColor: AppTheme.aiBlue,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AiSearchField(
                              controller: _searchController,
                              hintText: copy.isEnglish
                                  ? 'Search sales by product or customer...'
                                  : 'ابحث باسم المنتج أو اسم العميل...',
                              onClear: _searchController.clear,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<SalesPeriodFilter>(
                              initialValue: _periodFilter,
                              dropdownColor: AppTheme.aiCardElevated,
                              style: const TextStyle(
                                  color: AppTheme.aiTextPrimary,
                                  fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: copy.isEnglish
                                    ? 'Time Period'
                                    : 'فترة العمليات',
                                filled: true,
                                fillColor: AppTheme.aiCardElevated,
                              ),
                              items: SalesPeriodFilter.values
                                  .map(
                                    (filter) => DropdownMenuItem(
                                      value: filter,
                                      child: Text(_periodLabel(filter, copy)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _periodFilter = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            copy.salesHistoryResultCount(filteredRows.length),
                            style: const TextStyle(
                              color: AppTheme.aiGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          AiActionButton(
                            label: copy.isEnglish
                                ? 'New Sale'
                                : 'تسجيل عملية مبيعات',
                            icon: Icons.add_shopping_cart_rounded,
                            color: AppTheme.aiGold,
                            isSmall: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const DocumentsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (snapshot.hasError)
                        _buildErrorState(context, copy, snapshot.error)
                      else if (!hasData &&
                          snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.aiGold))
                      else if (originalRows.isEmpty)
                        _buildEmptyState(context, copy)
                      else if (filteredRows.isEmpty)
                        PremiumCard(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              copy.isEnglish
                                  ? 'No matching sales records found.'
                                  : 'لا توجد سجلات مبيعات مطابقة لبحثك وتصفيتك.',
                              style: const TextStyle(
                                  color: AppTheme.aiTextSecondary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        ...filteredRows.map((row) {
                          final totalProfit = _toDouble(row['total_profit']);
                          final qty = _toInt(row['qty']);
                          final unitPrice = _toDouble(row['selling_price']);
                          final totalSale = _toDouble(row['total_sale']);
                          final currencyCode =
                              row['currency_code']?.toString().trim();
                          final customerName =
                              row['customer_name']?.toString().trim() ?? '';
                          final saleNote =
                              row['sale_note']?.toString().trim() ?? '';
                          final productName =
                              row['product_name']?.toString().trim() ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PremiumCard(
                              padding: const EdgeInsets.all(20),
                              border: Border.all(
                                color: AppTheme.aiGold.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppTheme.aiGold
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.aiGold
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.point_of_sale_rounded,
                                      color: AppTheme.aiGold,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                productName.isEmpty
                                                    ? copy
                                                        .salesHistoryProductFallback()
                                                    : productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: AppTheme.aiTextPrimary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  copy.isEnglish
                                                      ? 'Sale total'
                                                      : 'إجمالي البيع',
                                                  style: const TextStyle(
                                                    color: AppTheme.aiTextMuted,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  AppFormatters.currency(
                                                    totalSale,
                                                    currencyLabel: currencyCode,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                    color: AppTheme.aiGold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  copy.isEnglish
                                                      ? 'Profit'
                                                      : 'الربح',
                                                  style: const TextStyle(
                                                    color: AppTheme.aiTextMuted,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  AppFormatters.currency(
                                                    totalProfit,
                                                    currencyLabel: currencyCode,
                                                  ),
                                                  style: TextStyle(
                                                    color: totalProfit >= 0
                                                        ? AppTheme.aiGreen
                                                        : AppTheme.aiRed,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: [
                                            Text(
                                              copy.salesHistoryQty(qty),
                                              style: const TextStyle(
                                                color: AppTheme.aiTextSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              copy.salesHistoryUnitPrice(
                                                AppFormatters.currency(
                                                  unitPrice,
                                                  currencyLabel: currencyCode,
                                                ),
                                              ),
                                              style: const TextStyle(
                                                color: AppTheme.aiTextSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (customerName.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            copy.salesHistoryCustomer(
                                                customerName),
                                            style: const TextStyle(
                                              color: AppTheme.aiTextSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                        if (saleNote.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            copy.salesHistoryNote(saleNote),
                                            style: const TextStyle(
                                              color: AppTheme.aiTextSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          AppFormatters.dateTimeString(
                                            row['date']?.toString(),
                                          ),
                                          style: const TextStyle(
                                            color: AppTheme.aiTextMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
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
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.aiRed, size: 48),
            const SizedBox(height: 16),
            Text(
              copy.isEnglish
                  ? 'Error loading sales history'
                  : 'فشل تحميل بيانات المبيعات من الخادم.',
              style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
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
    return Column(
      children: [
        AiMobileEmptyState(
          icon: Icons.point_of_sale_rounded,
          title: copy.isEnglish ? 'No sales yet' : 'لا توجد مبيعات بعد',
          subtitle: copy.isEnglish
              ? 'Start by registering your first sale.'
              : 'ابدأ بتسجيل أول عملية مبيعات.',
          actionLabel: copy.isEnglish ? 'New Sale' : 'تسجيل عملية مبيعات',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DocumentsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                );
              },
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(copy.t('navInventory')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectionCenterCard(BuildContext context, AppCopy copy) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const collection.CollectionCenterScreen()));
      },
      child: PremiumCard(
        padding: const EdgeInsets.all(0),
        gradient: AppTheme.commandGradient(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.aiRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.aiRed),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.t('collectionCenterTitle'),
                      style: const TextStyle(
                        color: AppTheme.aiTextPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.isEnglish
                          ? 'Manage overdue invoices and high-risk customers'
                          : 'إدارة الفواتير المتأخرة والعملاء تحت المراقبة',
                      style: const TextStyle(
                        color: AppTheme.aiTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.aiTextMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(SalesPeriodFilter filter, AppCopy copy) {
    switch (filter) {
      case SalesPeriodFilter.all:
        return copy.t('allPeriods');
      case SalesPeriodFilter.today:
        return copy.t('today');
      case SalesPeriodFilter.last7Days:
        return copy.t('last7Days');
      case SalesPeriodFilter.last30Days:
        return copy.t('last30Days');
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
