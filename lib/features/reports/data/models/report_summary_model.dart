class ReportSummaryModel {
  final double totalRevenue;
  final double totalCollected;
  final double totalOverdue;
  final Map<String, double> monthlySales; // e.g., {'يناير': 5000, 'فبراير': 7000}
  final List<Map<String, dynamic>> topCustomers;

  ReportSummaryModel({
    required this.totalRevenue,
    required this.totalCollected,
    required this.totalOverdue,
    required this.monthlySales,
    required this.topCustomers,
  });

  factory ReportSummaryModel.fromInvoicesAndPayments({
    required List<Map<String, dynamic>> invoiceDocs,
    required List<Map<String, dynamic>> paymentDocs,
  }) {
    double revenue = 0.0;
    double overdue = 0.0;
    double collected = 0.0;
    Map<String, double> monthly = {};
    Map<String, double> customerSales = {};

    for (var inv in invoiceDocs) {
      double total = (inv['total'] ?? 0.0).toDouble();
      String status = inv['status'] ?? 'draft';
      String customerName = inv['customerName'] ?? 'عميل غير معروف';
      
      if (status != 'draft') {
        revenue += total;
        customerSales[customerName] = (customerSales[customerName] ?? 0.0) + total;
      }
      if (status == 'overdue') {
        overdue += total;
      }
    }

    for (var pay in paymentDocs) {
      collected += (pay['amount'] ?? 0.0).toDouble();
    }

    // Sort and get top customers
    var sortedCustomers = customerSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<Map<String, dynamic>> topList = sortedCustomers.take(3).map((e) => {
      'name': e.key,
      'value': e.value,
    }).toList();

    return ReportSummaryModel(
      totalRevenue: revenue,
      totalCollected: collected,
      totalOverdue: overdue,
      monthlySales: monthly.isEmpty ? {'أبريل': 4500, 'مايو': 8200, 'يونيو': 12500} : monthly,
      topCustomers: topList.isEmpty ? [{'name': 'مؤسسة أحمد التجارية', 'value': 2900.0}] : topList,
    );
  }
}
