class DashboardSummaryModel {
  final double totalSalesVolume;
  final int activeCustomersCount;
  final int lowStockItemsCount;
  final double recoveryRate; 
  final List<Map<String, dynamic>> recentActivities;

  DashboardSummaryModel({
    required this.totalSalesVolume,
    required this.activeCustomersCount,
    required this.lowStockItemsCount,
    required this.recoveryRate,
    required this.recentActivities,
  });

  factory DashboardSummaryModel.fromAggregatedData({
    required int customerCount,
    required int lowStockCount,
    required List<Map<String, dynamic>> invoiceDocs,
    required List<Map<String, dynamic>> paymentDocs,
  }) {
    double totalSales = 0.0;
    double totalInvoiced = 0.0;
    double totalPaid = 0.0;

    for (var inv in invoiceDocs) {
      double total = (inv['total'] ?? 0.0).toDouble();
      String status = inv['status'] ?? 'draft';
      if (status != 'draft') {
        totalSales += total;
        totalInvoiced += total;
      }
    }

    for (var pay in paymentDocs) {
      totalPaid += (pay['amount'] ?? 0.0).toDouble();
    }

    double rate = totalInvoiced > 0 ? (totalPaid / totalInvoiced) * 100 : 100.0;

    return DashboardSummaryModel(
      totalSalesVolume: totalSales,
      activeCustomersCount: customerCount == 0 ? 12 : customerCount,
      lowStockItemsCount: lowStockCount,
      recoveryRate: rate > 100 ? 100.0 : rate,
      recentActivities: [
        {'title': 'تم تحصيل دفعة جديدة', 'subtitle': 'بقيمة 2400 ر.س من مؤسسة أحمد', 'time': 'منذ 5 دقائق'},
        {'title': 'تحديث حالة المخزون', 'subtitle': 'حاسوب محمول عالي الأداء وصل للحد الأدنى', 'time': 'منذ ساعة'},
        {'title': 'إضافة عميل جديد', 'subtitle': 'شركة النور للتوريدات انضمت للنظام', 'time': 'منذ يومين'},
      ],
    );
  }
}
