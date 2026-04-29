import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/repositories/product_repository.dart';

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
    _searchController.addListener(_handleSearchChanged);
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

  Future<void> _reloadSales({bool showError = false}) async {
    try {
      await _productRepository.getSalesRecords();
    } catch (error) {
      if (!mounted || !showError) return;
      AppMessages.error(
        context,
        '${AppCopy.of(context).t('loadSalesHistoryError')}\n$error',
      );
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    final query = _searchQuery;
    final now = DateTime.now();

    return rows.where((row) {
      final productName = row['product_name']?.toString().toLowerCase() ?? '';
      final customerName = row['customer_name']?.toString().toLowerCase() ?? '';
      final matchesSearch =
          query.isEmpty || productName.contains(query) || customerName.contains(query);

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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final secondary = AppTheme.textSecondaryFor(context);
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.t('salesHistoryTitle'))),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _productRepository.watchSalesRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.danger,
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          copy.t('loadSalesHistoryError'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: secondary),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reloadSales,
                          child: Text(copy.t('retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final rows = _applyFilters(snapshot.data ?? const []);

          return RefreshIndicator(
            onRefresh: () => _reloadSales(showError: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: copy.t('searchSalesHint'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.t('recordPeriod'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<SalesPeriodFilter>(
                          initialValue: _periodFilter,
                          dropdownColor: AppTheme.surfaceFor(context),
                          style: TextStyle(
                            color: onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          iconEnabledColor: secondary,
                          decoration: InputDecoration(
                            labelText: copy.t('period'),
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
                ),
                const SizedBox(height: 14),
                Text(
                  copy.salesHistoryResultCount(rows.length),
                  style: TextStyle(
                    color: secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          copy.t('noMatchingSales'),
                          style: TextStyle(color: secondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  ...rows.map((row) {
                    final totalProfit = _toDouble(row['total_profit']);
                    final qty = _toInt(row['qty']);
                    final unitPrice = _toDouble(row['selling_price']);
                    final totalSale = _toDouble(row['total_sale']);
                    final currencyCode = row['currency_code']?.toString().trim();
                    final customerName =
                        row['customer_name']?.toString().trim() ?? '';
                    final saleNote = row['sale_note']?.toString().trim() ?? '';
                    final productName =
                        row['product_name']?.toString().trim() ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.16),
                                ),
                              ),
                              child: const Icon(
                                Icons.point_of_sale_rounded,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          productName.isEmpty
                                              ? copy.salesHistoryProductFallback()
                                              : productName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            AppFormatters.currency(
                                              totalSale,
                                              currencyLabel: currencyCode,
                                            ),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppFormatters.currency(
                                              totalProfit,
                                              currencyLabel: currencyCode,
                                            ),
                                            style: TextStyle(
                                              color: totalProfit >= 0
                                                  ? AppTheme.success
                                                  : AppTheme.danger,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
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
                                        style: TextStyle(
                                          color: secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        copy.salesHistoryUnitPrice(
                                          AppFormatters.currency(
                                            unitPrice,
                                            currencyLabel: currencyCode,
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((currencyCode ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      copy.salesHistoryCurrency(currencyCode!),
                                      style: TextStyle(
                                        color: secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (customerName.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      copy.salesHistoryCustomer(customerName),
                                      style: TextStyle(
                                        color: secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (saleNote.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      copy.salesHistoryNote(saleNote),
                                      style: TextStyle(
                                        color: secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    AppFormatters.dateTimeString(
                                      row['date']?.toString(),
                                    ),
                                    style: TextStyle(
                                      color: secondary,
                                      fontSize: 12,
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
          );
        },
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
