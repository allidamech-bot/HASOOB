import 'dart:math';

import '../../database/database_helper.dart';
import '../../models/product_model.dart';
import 'report_models.dart';

enum ReportPeriodFilter { all, last7Days, last30Days, today }

class ReportService {
  const ReportService();

  Future<ReportsSnapshot> buildSnapshot({
    required String businessId,
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final products =
        (await DBHelper.getProducts(businessId)).map(ProductModel.fromMap).toList();
    final salesRecords = await DBHelper.getSalesRecords(businessId);
    final accounts = await DBHelper.getTrialBalance(businessId);
    final journalEntries = await DBHelper.getJournalEntries(businessId);
    final filteredSales = _filterSalesRecords(
      salesRecords,
      period: period,
      productId: productId,
    );
    final topProductsRows = _buildTopProductsRows(filteredSales, limit: 5);

    final totalProducts = products.length;
    final totalQuantity = products.fold<int>(0, (sum, item) => sum + item.stockQty);
    final totalStockValue =
        products.fold<double>(0, (sum, item) => sum + item.totalStockValue);
    final totalSales = filteredSales.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['total_sale']),
    );
    final netProfitEstimate = productId == null || productId.isEmpty
        ? products.fold<double>(0, (sum, item) => sum + item.totalExpectedProfit)
        : products
            .where((item) => item.id == productId)
            .fold<double>(0, (sum, item) => sum + item.totalExpectedProfit);
    final realizedProfit = filteredSales.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['total_profit']),
    );

    final lowStockItems = (productId == null || productId.isEmpty
            ? products
            : products.where((product) => product.id == productId))
        .where((product) => product.isLowStock)
        .toList()
      ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

    final bestSellingProducts = topProductsRows
        .map(
          (row) => ProductPerformance(
            productId: row['product_id']?.toString() ?? '',
            name: row['product_name']?.toString() ?? 'غير معروف',
            soldQuantity: _toInt(row['sold_qty']),
            totalSales: _toDouble(row['total_sale']),
            totalProfit: _toDouble(row['total_profit']),
          ),
        )
        .toList();

    final recentSales = filteredSales.take(6).toList();

    return ReportsSnapshot(
      products: products,
      salesRecords: filteredSales,
      accounts: accounts,
      journalEntries: journalEntries,
      totalProducts: totalProducts,
      totalQuantity: totalQuantity,
      totalStockValue: totalStockValue,
      totalSales: totalSales,
      netProfitEstimate: netProfitEstimate,
      realizedProfit: realizedProfit,
      lowStockItems: lowStockItems,
      bestSellingProducts: bestSellingProducts,
      recentSales: recentSales,
      salesTrend: _buildSalesTrend(filteredSales),
      profitTrend: _buildProfitTrend(filteredSales),
      stockDistribution: _buildStockDistribution(
        productId == null || productId.isEmpty
            ? products
            : products.where((item) => item.id == productId).toList(),
      ),
      topProductChart: _buildTopProductChart(bestSellingProducts),
      trialBalanceSummary: _buildTrialBalanceSummary(accounts, journalEntries),
    );
  }

  List<Map<String, dynamic>> _filterSalesRecords(
    List<Map<String, dynamic>> salesRecords, {
    required ReportPeriodFilter period,
    String? productId,
  }) {
    final now = DateTime.now();
    return salesRecords.where((row) {
      if (productId != null && productId.isNotEmpty) {
        if ((row['product_id']?.toString() ?? '') != productId) return false;
      }

      if (period == ReportPeriodFilter.all) return true;

      final date = DateTime.tryParse(row['date']?.toString() ?? '')?.toLocal();
      if (date == null) return false;

      switch (period) {
        case ReportPeriodFilter.all:
          return true;
        case ReportPeriodFilter.today:
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case ReportPeriodFilter.last7Days:
          return !date.isBefore(now.subtract(const Duration(days: 7)));
        case ReportPeriodFilter.last30Days:
          return !date.isBefore(now.subtract(const Duration(days: 30)));
      }
    }).toList()
      ..sort(
        (a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''),
      );
  }

  List<Map<String, dynamic>> _buildTopProductsRows(
    List<Map<String, dynamic>> salesRecords, {
    required int limit,
  }) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final row in salesRecords) {
      final productId = row['product_id']?.toString() ?? '';
      final key = '$productId::${row['product_name'] ?? ''}';
      final current = grouped.putIfAbsent(
        key,
        () => {
          'product_id': productId,
          'product_name': row['product_name'],
          'sold_qty': 0,
          'total_sale': 0.0,
          'total_profit': 0.0,
        },
      );
      current['sold_qty'] = _toInt(current['sold_qty']) + _toInt(row['qty']);
      current['total_sale'] =
          _toDouble(current['total_sale']) + _toDouble(row['total_sale']);
      current['total_profit'] =
          _toDouble(current['total_profit']) + _toDouble(row['total_profit']);
    }

    final rows = grouped.values.toList()
      ..sort((a, b) {
        final soldCompare = _toInt(b['sold_qty']).compareTo(_toInt(a['sold_qty']));
        if (soldCompare != 0) return soldCompare;
        return _toDouble(b['total_sale']).compareTo(_toDouble(a['total_sale']));
      });

    return rows.take(limit).toList();
  }

  List<MetricPoint> _buildSalesTrend(List<Map<String, dynamic>> salesRecords) {
    final grouped = <String, double>{};
    final sorted = List<Map<String, dynamic>>.from(salesRecords)
      ..sort(
        (a, b) => (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''),
      );

    for (final row in sorted) {
      final label = _shortDate(row['date']?.toString());
      grouped[label] = (grouped[label] ?? 0) + _toDouble(row['total_sale']);
    }

    return grouped.entries.length <= 7
        ? grouped.entries
            .map((entry) => MetricPoint(label: entry.key, value: entry.value))
            .toList()
        : grouped.entries
            .skip(max(0, grouped.length - 7))
            .map((entry) => MetricPoint(label: entry.key, value: entry.value))
            .toList();
  }

  List<MetricPoint> _buildProfitTrend(List<Map<String, dynamic>> salesRecords) {
    final grouped = <String, double>{};
    final sorted = List<Map<String, dynamic>>.from(salesRecords)
      ..sort(
        (a, b) => (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''),
      );

    for (final row in sorted) {
      final label = _shortDate(row['date']?.toString());
      grouped[label] = (grouped[label] ?? 0) + _toDouble(row['total_profit']);
    }

    return grouped.entries
        .skip(max(0, grouped.length - 7))
        .map((entry) => MetricPoint(label: entry.key, value: entry.value))
        .toList();
  }

  List<MetricPoint> _buildStockDistribution(List<ProductModel> products) {
    final inStock = products.where((item) => !item.isLowStock && !item.isOutOfStock).length;
    final low = products.where((item) => item.isLowStock && !item.isOutOfStock).length;
    final out = products.where((item) => item.isOutOfStock).length;

    return [
      MetricPoint(label: 'مستقر', value: inStock.toDouble()),
      MetricPoint(label: 'منخفض', value: low.toDouble()),
      MetricPoint(label: 'نافد', value: out.toDouble()),
    ];
  }

  List<MetricPoint> _buildTopProductChart(List<ProductPerformance> items) {
    return items
        .map(
          (item) => MetricPoint(
            label: item.name,
            value: item.totalSales,
            secondaryValue: item.totalProfit,
          ),
        )
        .toList();
  }

  TrialBalanceSummary _buildTrialBalanceSummary(
    List<Map<String, dynamic>> accounts,
    List<Map<String, dynamic>> journalEntries,
  ) {
    double totalDebit = 0;
    double totalCredit = 0;

    for (final account in accounts) {
      final balance = _toDouble(account['balance']);
      if (balance >= 0) {
        totalDebit += balance;
      } else {
        totalCredit += balance.abs();
      }
    }

    return TrialBalanceSummary(
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      isBalanced: (totalDebit - totalCredit).abs() < 0.01,
      entriesCount: journalEntries.length,
    );
  }

  String _shortDate(String? value) {
    if (value == null || value.isEmpty) return '--';
    try {
      final date = DateTime.parse(value).toLocal();
      return '${date.month}/${date.day}';
    } catch (_) {
      return value;
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
