import 'ai_evidence_bundle.dart';

class AiFinancialSnapshot {
  final double? revenue;
  final double? expenses;
  final double? profit;
  final double? pendingInvoices;
  final int? overdueInvoices;
  final String? inventoryHealth;
  final int? lowStockProducts;
  final String? customerRisk;
  final AiEvidenceConfidence confidence;
  final List<String> missingData;

  const AiFinancialSnapshot({
    this.revenue,
    this.expenses,
    this.profit,
    this.pendingInvoices,
    this.overdueInvoices,
    this.inventoryHealth,
    this.lowStockProducts,
    this.customerRisk,
    required this.confidence,
    this.missingData = const [],
  });

  factory AiFinancialSnapshot.fromEvidence(AiEvidenceBundle evidence) {
    final summary = _summary(evidence, 'getFinancialSummary');
    final invoices = _summary(evidence, 'getInvoices');
    final products = _summary(evidence, 'getProducts');
    final customers = _summary(evidence, 'getCustomers');

    final missing = <String>{...evidence.missingEvidence};
    if (summary.isEmpty) missing.add('financial summary');
    if (invoices.isEmpty) missing.add('invoices');
    if (products.isEmpty) missing.add('inventory/products');
    if (customers.isEmpty) missing.add('customers');

    final invoiceRecords = _records(invoices);
    final productRecords = _records(products);
    final revenue = _number(summary['totalIncome']);
    final expenses = _number(summary['totalExpenses']);
    final profit = _number(summary['totalProfit']);
    final pendingInvoices = _number(invoices['outstanding']) ??
        _number(summary['accountsReceivable']);
    final overdueInvoices = invoices.isEmpty
        ? null
        : invoiceRecords.where(_isOverdueInvoice).length;
    final lowStockProducts = products.isEmpty
        ? null
        : productRecords.where(_isLowStockProduct).length;
    final customerOutstanding = _number(customers['totalOutstanding']);

    return AiFinancialSnapshot(
      revenue: revenue,
      expenses: expenses,
      profit: profit,
      pendingInvoices: pendingInvoices,
      overdueInvoices: overdueInvoices,
      inventoryHealth: products.isEmpty
          ? null
          : (lowStockProducts != null && lowStockProducts > 0
              ? 'needs_attention'
              : 'healthy'),
      lowStockProducts: lowStockProducts,
      customerRisk: customers.isEmpty
          ? null
          : (customerOutstanding != null && customerOutstanding > 0
              ? 'open_balances'
              : 'low'),
      confidence: _confidence(
        hasSummary: summary.isNotEmpty,
        hasInvoices: invoices.isNotEmpty,
        hasProducts: products.isNotEmpty,
        hasCustomers: customers.isNotEmpty,
      ),
      missingData: missing.toList(),
    );
  }

  bool get hasEvidence {
    return revenue != null ||
        expenses != null ||
        profit != null ||
        pendingInvoices != null ||
        overdueInvoices != null ||
        inventoryHealth != null ||
        lowStockProducts != null ||
        customerRisk != null;
  }

  static AiEvidenceConfidence _confidence({
    required bool hasSummary,
    required bool hasInvoices,
    required bool hasProducts,
    required bool hasCustomers,
  }) {
    final available = [hasSummary, hasInvoices, hasProducts, hasCustomers]
        .where((value) => value)
        .length;
    if (available >= 4) return AiEvidenceConfidence.high;
    if (available >= 2) return AiEvidenceConfidence.medium;
    return AiEvidenceConfidence.low;
  }

  static Map<String, dynamic> _summary(
    AiEvidenceBundle evidence,
    String toolName,
  ) {
    final value = evidence.summaries[toolName];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<Map<String, dynamic>> _records(Map<String, dynamic> summary) {
    final records = summary['records'];
    if (records is! List) return const [];
    return records
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static bool _isOverdueInvoice(Map<String, dynamic> invoice) {
    final status = invoice['status']?.toString().toLowerCase();
    final remaining = _number(invoice['remaining_amount']) ??
        _number(invoice['remainingAmount']) ??
        (_number(invoice['total']) ?? 0) -
            (_number(invoice['paid_amount']) ?? 0);
    if (remaining <= 0) return false;
    if (status == 'overdue') return true;
    final dueDate = DateTime.tryParse(
      (invoice['due_date'] ?? invoice['dueDate'] ?? '').toString(),
    );
    return dueDate != null && dueDate.isBefore(DateTime.now());
  }

  static bool _isLowStockProduct(Map<String, dynamic> product) {
    final threshold = _number(product['low_stock_threshold']) ??
        _number(product['lowStockThreshold']) ??
        0;
    final stock =
        _number(product['stock_qty']) ?? _number(product['stock']) ?? 0;
    return threshold > 0 && stock <= threshold;
  }

  static double? _number(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
