import 'ai_evidence_bundle.dart';

enum AiCustomerCreditRiskLevel {
  low,
  medium,
  high,
  critical,
}

class AiCustomerCreditSignal {
  final String customerId;
  final String customerName;
  final int riskScore;
  final AiCustomerCreditRiskLevel riskLevel;
  final double paymentReliability;
  final int invoiceCount;
  final int overdueCount;
  final double overdueFrequency;
  final double averagePaymentDelayDays;
  final double outstandingBalance;
  final double concentrationRisk;
  final String explanation;
  final List<String> evidence;
  final AiEvidenceConfidence confidence;
  final String recommendedAction;

  const AiCustomerCreditSignal({
    required this.customerId,
    required this.customerName,
    required this.riskScore,
    required this.riskLevel,
    required this.paymentReliability,
    required this.invoiceCount,
    required this.overdueCount,
    required this.overdueFrequency,
    required this.averagePaymentDelayDays,
    required this.outstandingBalance,
    required this.concentrationRisk,
    required this.explanation,
    required this.evidence,
    required this.confidence,
    required this.recommendedAction,
  });

  String get riskLabel {
    switch (riskLevel) {
      case AiCustomerCreditRiskLevel.low:
        return 'Low Risk';
      case AiCustomerCreditRiskLevel.medium:
        return 'Medium Risk';
      case AiCustomerCreditRiskLevel.high:
        return 'High Risk';
      case AiCustomerCreditRiskLevel.critical:
        return 'Critical';
    }
  }
}

class AiCustomerCreditReport {
  final List<AiCustomerCreditSignal> customers;
  final List<String> evidenceSources;
  final AiEvidenceConfidence confidence;
  final String scoringModel;

  const AiCustomerCreditReport({
    required this.customers,
    required this.evidenceSources,
    required this.confidence,
    required this.scoringModel,
  });

  AiCustomerCreditSignal? get riskiestCustomer =>
      customers.isEmpty ? null : customers.first;
}

class AiCustomerCreditIntelligence {
  static const scoringModel =
      'Risk score 0-100 = overdue frequency up to 30 points, average payment delay up to 25, outstanding balance exposure up to 20, concentration risk up to 15, and weak payment reliability up to 10. Lower is safer.';

  AiCustomerCreditReport analyze(AiEvidenceBundle evidence) {
    final customerSummary = _summary(evidence, 'getCustomers');
    final invoiceSummary = _summary(evidence, 'getInvoices');
    final customers = _records(customerSummary);
    final invoices = _records(invoiceSummary)
        .where((invoice) => !_isDraftOrCancelled(invoice))
        .toList();
    final summarizedOutstanding = _number(customerSummary['totalOutstanding']);
    final totalOutstanding = summarizedOutstanding > 0
        ? summarizedOutstanding
        : customers.fold<double>(
            0,
            (sum, row) => sum + _number(row['outstanding_balance']),
          );

    final signals = customers.map((customer) {
      final customerId = customer['id']?.toString() ?? '';
      final rawName = customer['name']?.toString().trim();
      final customerName =
          rawName != null && rawName.isNotEmpty ? rawName : 'Unknown customer';
      final customerInvoices = invoices.where((invoice) {
        final invoiceCustomerId =
            (invoice['customer_id'] ?? invoice['customerId'])?.toString();
        final invoiceCustomerName =
            (invoice['customer_name'] ?? invoice['customerName'])
                ?.toString()
                .toLowerCase();
        return (customerId.isNotEmpty && invoiceCustomerId == customerId) ||
            (invoiceCustomerName != null &&
                invoiceCustomerName == customerName.toLowerCase());
      }).toList();
      return _scoreCustomer(
        customerId: customerId,
        customerName: customerName,
        customer: customer,
        invoices: customerInvoices,
        totalOutstanding: totalOutstanding,
        confidence: _confidenceFor(
          evidence: evidence,
          hasCustomer: customer.isNotEmpty,
          hasInvoices: invoiceSummary.isNotEmpty,
        ),
      );
    }).toList()
      ..sort((a, b) {
        final scoreCompare = b.riskScore.compareTo(a.riskScore);
        if (scoreCompare != 0) return scoreCompare;
        return b.outstandingBalance.compareTo(a.outstandingBalance);
      });

    return AiCustomerCreditReport(
      customers: signals,
      evidenceSources: evidence.executedTools
          .where((tool) => tool.success)
          .map((tool) => '${tool.toolName}: ${tool.reason}')
          .toList(),
      confidence: _reportConfidence(evidence, customers, invoiceSummary),
      scoringModel: scoringModel,
    );
  }

  AiCustomerCreditSignal _scoreCustomer({
    required String customerId,
    required String customerName,
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> invoices,
    required double totalOutstanding,
    required AiEvidenceConfidence confidence,
  }) {
    final now = DateTime.now();
    final invoiceCount = invoices.length;
    final hasCustomerOutstanding = customer.containsKey('outstanding_balance');
    final outstandingBalance = hasCustomerOutstanding
        ? _number(customer['outstanding_balance'])
        : invoices.fold<double>(
            0,
            (sum, invoice) => sum + _remainingAmount(invoice),
          );
    final overdueInvoices = invoices.where((invoice) {
      return _isOverdue(invoice, now);
    }).toList();
    final overdueCount = overdueInvoices.length;
    final overdueFrequency =
        invoiceCount == 0 ? 0.0 : overdueCount / invoiceCount;
    final paidCount =
        invoices.where((invoice) => _remainingAmount(invoice) <= 0).length;
    final paymentReliability = invoiceCount == 0
        ? (outstandingBalance > 0 ? 0.6 : 1.0)
        : (paidCount + (1 - overdueFrequency)) / (invoiceCount + 1);
    final averagePaymentDelayDays = overdueInvoices.isEmpty
        ? 0.0
        : overdueInvoices
                .map((invoice) => _delayDays(invoice, now))
                .fold<double>(0, (sum, delay) => sum + delay) /
            overdueInvoices.length;
    final concentrationRisk =
        totalOutstanding <= 0 ? 0.0 : outstandingBalance / totalOutstanding;

    final score = _boundedScore(
      overdueFrequency * 30 +
          (averagePaymentDelayDays / 60).clamp(0, 1) * 25 +
          _balanceExposure(outstandingBalance) * 20 +
          concentrationRisk.clamp(0, 1) * 15 +
          (1 - paymentReliability).clamp(0, 1) * 10,
    );
    final level = _riskLevel(score);

    return AiCustomerCreditSignal(
      customerId: customerId,
      customerName: customerName,
      riskScore: score,
      riskLevel: level,
      paymentReliability: paymentReliability,
      invoiceCount: invoiceCount,
      overdueCount: overdueCount,
      overdueFrequency: overdueFrequency,
      averagePaymentDelayDays: averagePaymentDelayDays,
      outstandingBalance: outstandingBalance,
      concentrationRisk: concentrationRisk,
      explanation:
          '$customerName has $overdueCount overdue invoices out of $invoiceCount, '
          '${outstandingBalance.toStringAsFixed(2)} outstanding, and '
          '${(concentrationRisk * 100).toStringAsFixed(1)}% of total customer exposure.',
      evidence: [
        'Customer balance: ${outstandingBalance.toStringAsFixed(2)}',
        'Invoice history: $invoiceCount invoices',
        'Overdue frequency: ${(overdueFrequency * 100).toStringAsFixed(1)}%',
        'Average payment delay: ${averagePaymentDelayDays.toStringAsFixed(1)} days',
        'Concentration risk: ${(concentrationRisk * 100).toStringAsFixed(1)}%',
      ],
      confidence: confidence,
      recommendedAction: _recommendedAction(level),
    );
  }

  AiEvidenceConfidence _confidenceFor({
    required AiEvidenceBundle evidence,
    required bool hasCustomer,
    required bool hasInvoices,
  }) {
    if (!hasCustomer) return AiEvidenceConfidence.low;
    if (hasInvoices && evidence.confidenceLevel == AiEvidenceConfidence.high) {
      return AiEvidenceConfidence.high;
    }
    if (hasInvoices) return AiEvidenceConfidence.medium;
    return AiEvidenceConfidence.low;
  }

  AiEvidenceConfidence _reportConfidence(
    AiEvidenceBundle evidence,
    List<Map<String, dynamic>> customers,
    Map<String, dynamic> invoiceSummary,
  ) {
    if (customers.isEmpty) return AiEvidenceConfidence.low;
    if (invoiceSummary.isNotEmpty &&
        evidence.confidenceLevel == AiEvidenceConfidence.high) {
      return AiEvidenceConfidence.high;
    }
    if (invoiceSummary.isNotEmpty) return AiEvidenceConfidence.medium;
    return AiEvidenceConfidence.low;
  }

  AiCustomerCreditRiskLevel _riskLevel(int score) {
    if (score >= 75) return AiCustomerCreditRiskLevel.critical;
    if (score >= 55) return AiCustomerCreditRiskLevel.high;
    if (score >= 30) return AiCustomerCreditRiskLevel.medium;
    return AiCustomerCreditRiskLevel.low;
  }

  String _recommendedAction(AiCustomerCreditRiskLevel level) {
    switch (level) {
      case AiCustomerCreditRiskLevel.low:
        return 'Continue normal credit terms and monitor payment timing.';
      case AiCustomerCreditRiskLevel.medium:
        return 'Limit new credit until the oldest open invoices are followed up.';
      case AiCustomerCreditRiskLevel.high:
        return 'Pause additional credit and agree a collection plan before new orders.';
      case AiCustomerCreditRiskLevel.critical:
        return 'Stop extending credit until payment is received or secured.';
    }
  }

  double _balanceExposure(double outstanding) {
    if (outstanding <= 0) return 0;
    if (outstanding >= 10000) return 1;
    return outstanding / 10000;
  }

  int _boundedScore(double value) => value.round().clamp(0, 100);

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

  bool _isDraftOrCancelled(Map<String, dynamic> invoice) {
    final status = invoice['status']?.toString().toLowerCase();
    return status == 'draft' || status == 'cancelled';
  }

  bool _isOverdue(Map<String, dynamic> invoice, DateTime now) {
    if (_remainingAmount(invoice) <= 0) return false;
    final status = invoice['status']?.toString().toLowerCase();
    if (status == 'overdue') return true;
    final dueDate = _date(invoice['due_date'] ?? invoice['dueDate']);
    return dueDate != null && dueDate.isBefore(now);
  }

  double _delayDays(Map<String, dynamic> invoice, DateTime now) {
    final dueDate = _date(invoice['due_date'] ?? invoice['dueDate']);
    if (dueDate == null || dueDate.isAfter(now)) return 0;
    return now.difference(dueDate).inHours / 24;
  }

  double _remainingAmount(Map<String, dynamic> invoice) {
    final remaining =
        _number(invoice['remaining_amount'] ?? invoice['remainingAmount']);
    if (remaining > 0) return remaining;
    final total = _number(invoice['total'] ?? invoice['total_amount']);
    final paid = _number(invoice['paid_amount'] ?? invoice['paidAmount']);
    return (total - paid).clamp(0, double.infinity);
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double _number(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
