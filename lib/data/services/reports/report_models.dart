import '../../models/product.dart';

class MetricPoint {
  const MetricPoint({
    required this.label,
    required this.value,
    this.secondaryValue = 0,
  });

  final String label;
  final double value;
  final double secondaryValue;
}

class ProductPerformance {
  const ProductPerformance({
    required this.productId,
    required this.name,
    required this.soldQuantity,
    required this.totalSales,
    required this.totalProfit,
  });

  final String productId;
  final String name;
  final int soldQuantity;
  final double totalSales;
  final double totalProfit;
}

class TrialBalanceSummary {
  const TrialBalanceSummary({
    required this.totalDebit,
    required this.totalCredit,
    required this.isBalanced,
    required this.entriesCount,
  });

  final double totalDebit;
  final double totalCredit;
  final bool isBalanced;
  final int entriesCount;
}

class ReportsSnapshot {
  const ReportsSnapshot({
    required this.products,
    required this.salesRecords,
    required this.accounts,
    required this.journalEntries,
    required this.totalProducts,
    required this.totalQuantity,
    required this.totalStockValue,
    required this.totalSales,
    required this.netProfitEstimate,
    required this.realizedProfit,
    required this.lowStockItems,
    required this.bestSellingProducts,
    required this.recentSales,
    required this.salesTrend,
    required this.profitTrend,
    required this.stockDistribution,
    required this.topProductChart,
    required this.trialBalanceSummary,
  });

  final List<Product> products;
  final List<Map<String, dynamic>> salesRecords;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> journalEntries;
  final int totalProducts;
  final int totalQuantity;
  final double totalStockValue;
  final double totalSales;
  final double netProfitEstimate;
  final double realizedProfit;
  final List<Product> lowStockItems;
  final List<ProductPerformance> bestSellingProducts;
  final List<Map<String, dynamic>> recentSales;
  final List<MetricPoint> salesTrend;
  final List<MetricPoint> profitTrend;
  final List<MetricPoint> stockDistribution;
  final List<MetricPoint> topProductChart;
  final TrialBalanceSummary trialBalanceSummary;
}
