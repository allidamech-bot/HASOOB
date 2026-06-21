import '../data/tools/financial_tools.dart';
import 'ai_cfo_context_snapshot.dart';
import 'ai_cfo_conversation_intent.dart';
import 'ai_cfo_evidence.dart';

class AiCfoContextSnapshotBuilder {
  const AiCfoContextSnapshotBuilder({FinancialTools? financialTools})
      : _financialTools = financialTools;

  final FinancialTools? _financialTools;

  Future<AiCfoContextSnapshot> buildFromFinancialTools({
    required String businessId,
    required AiCfoConversationIntent intent,
  }) async {
    final tools = _financialTools ?? FinancialTools();
    final includeBusinessHealth =
        intent == AiCfoConversationIntent.businessHealth ||
            intent == AiCfoConversationIntent.explainEvidence;

    FinancialToolResult? financialSummary;
    FinancialToolResult? income;
    FinancialToolResult? expenses;
    FinancialToolResult? invoices;
    FinancialToolResult? customers;
    FinancialToolResult? products;

    if (includeBusinessHealth ||
        intent == AiCfoConversationIntent.cashflowReview) {
      financialSummary =
          await tools.getFinancialSummary(businessId: businessId);
      invoices = await tools.getInvoices(businessId: businessId, limit: 100);
    }
    if (includeBusinessHealth ||
        intent == AiCfoConversationIntent.profitReview) {
      income = await tools.getIncome(businessId: businessId, limit: 100);
      expenses = await tools.getExpenses(businessId: businessId, limit: 100);
    }
    if (includeBusinessHealth ||
        intent == AiCfoConversationIntent.inventoryReview) {
      products = await tools.getProducts(businessId: businessId, limit: 100);
    }
    if (includeBusinessHealth ||
        intent == AiCfoConversationIntent.receivablesReview) {
      customers = await tools.getCustomers(businessId: businessId, limit: 100);
      invoices ??= await tools.getInvoices(businessId: businessId, limit: 100);
    }

    return buildFromToolResults(
      financialSummary: financialSummary,
      income: income,
      expenses: expenses,
      invoices: invoices,
      customers: customers,
      products: products,
      noteMissingSources: false,
    );
  }

  AiCfoContextSnapshot buildFromToolResults({
    FinancialToolResult? financialSummary,
    FinancialToolResult? income,
    FinancialToolResult? expenses,
    FinancialToolResult? invoices,
    FinancialToolResult? customers,
    FinancialToolResult? products,
    bool noteMissingSources = true,
  }) {
    final notes = <String>[];
    final cashSummary = <AiCfoEvidence>[];
    final salesSummary = <AiCfoEvidence>[];
    final inventorySummary = <AiCfoEvidence>[];
    final receivablesSummary = <AiCfoEvidence>[];
    final recentLedgerSignals = <AiCfoEvidence>[];
    final recentSalesSignals = <AiCfoEvidence>[];

    _mapFinancialSummary(
      financialSummary,
      cashSummary: cashSummary,
      salesSummary: salesSummary,
      receivablesSummary: receivablesSummary,
      notes: notes,
      noteMissingSource: noteMissingSources,
    );
    _mapIncome(
      income,
      salesSummary: salesSummary,
      recentSalesSignals: recentSalesSignals,
      notes: notes,
      noteMissingSource: noteMissingSources,
    );
    _mapExpenses(
      expenses,
      recentLedgerSignals: recentLedgerSignals,
      notes: notes,
      noteMissingSource: noteMissingSources,
    );
    _mapInvoices(
      invoices,
      cashSummary: cashSummary,
      receivablesSummary: receivablesSummary,
      notes: notes,
      noteMissingSource: noteMissingSources,
    );
    _mapCustomers(
      customers,
      receivablesSummary: receivablesSummary,
      notes: notes,
      noteMissingSource: noteMissingSources,
    );
    _mapProducts(
      products,
      inventorySummary: inventorySummary,
      notes: notes,
      noteMissingSource: noteMissingSources,
    );

    final evidence = [
      ...cashSummary,
      ...salesSummary,
      ...inventorySummary,
      ...receivablesSummary,
      ...recentLedgerSignals,
      ...recentSalesSignals,
    ];
    if (evidence.isEmpty) {
      return AiCfoContextSnapshot(
        dataCompletenessNotes: notes.isEmpty
            ? const ['No financial evidence is available.']
            : notes.toSet().toList(),
      );
    }

    return AiCfoContextSnapshot(
      cashSummary: cashSummary,
      salesSummary: salesSummary,
      inventorySummary: inventorySummary,
      receivablesSummary: receivablesSummary,
      recentLedgerSignals: recentLedgerSignals,
      recentSalesSignals: recentSalesSignals,
      dataCompletenessNotes: notes.toSet().toList(),
    );
  }

  void _mapFinancialSummary(
    FinancialToolResult? result, {
    required List<AiCfoEvidence> cashSummary,
    required List<AiCfoEvidence> salesSummary,
    required List<AiCfoEvidence> receivablesSummary,
    required List<String> notes,
    required bool noteMissingSource,
  }) {
    final data = _dataMap(
      result,
      'Financial summary',
      notes,
      noteMissingSource: noteMissingSource,
    );
    if (data == null) return;
    const source = 'FinancialTools.getFinancialSummary';
    cashSummary.addAll([
      _evidence(
        label: 'Net cash flow',
        value: _money(data['netCashFlow']),
        source: source,
        confidence: AiCfoEvidenceConfidence.medium,
        explanation:
            'Derived from income and expense totals returned by the financial summary tool.',
      ),
      _evidence(
        label: 'Accounts receivable',
        value: _money(data['accountsReceivable']),
        source: source,
        confidence: AiCfoEvidenceConfidence.medium,
        explanation:
            'Derived from invoice outstanding balances in the financial summary tool.',
      ),
    ]);
    salesSummary.addAll([
      _evidence(
        label: 'Total income',
        value: _money(data['totalIncome']),
        source: source,
        confidence: AiCfoEvidenceConfidence.medium,
        explanation: 'Read from the financial summary tool.',
      ),
      _evidence(
        label: 'Total profit',
        value: _money(data['totalProfit']),
        source: source,
        confidence: AiCfoEvidenceConfidence.medium,
        explanation: 'Read from the financial summary tool.',
      ),
      _evidence(
        label: 'Profit margin',
        value: '${_toDouble(data['profitMargin']).toStringAsFixed(1)}%',
        source: source,
        confidence: AiCfoEvidenceConfidence.medium,
        explanation:
            'Calculated by the existing financial summary tool from income and profit.',
      ),
    ]);
    receivablesSummary.add(
      _evidence(
        label: 'Accounts receivable',
        value: _money(data['accountsReceivable']),
        source: source,
        confidence: AiCfoEvidenceConfidence.medium,
        explanation:
            'Derived from invoice outstanding balances in the financial summary tool.',
      ),
    );
    notes.add('Financial summary is aggregate-only without row-level detail.');
  }

  void _mapIncome(
    FinancialToolResult? result, {
    required List<AiCfoEvidence> salesSummary,
    required List<AiCfoEvidence> recentSalesSignals,
    required List<String> notes,
    required bool noteMissingSource,
  }) {
    final data = _dataMap(
      result,
      'Income records',
      notes,
      noteMissingSource: noteMissingSource,
    );
    if (data == null) return;
    const source = 'FinancialTools.getIncome';
    final count = _toInt(data['count']);
    final confidence =
        count > 0 ? AiCfoEvidenceConfidence.high : AiCfoEvidenceConfidence.low;
    if (count == 0) {
      notes.add('Income tool returned no sales records.');
    }
    salesSummary.addAll([
      _evidence(
        label: 'Sales record count',
        value: count.toString(),
        source: source,
        confidence: confidence,
        explanation: 'Count returned by the income tool.',
      ),
      _evidence(
        label: 'Sales total',
        value: _money(data['total']),
        source: source,
        confidence: confidence,
        explanation: 'Sum of sales records returned by the income tool.',
      ),
      _evidence(
        label: 'Gross profit',
        value: _money(data['profit']),
        source: source,
        confidence: confidence,
        explanation: 'Sum of profit values returned by the income tool.',
      ),
    ]);
    recentSalesSignals.add(
      _evidence(
        label: 'Recent sales records',
        value: count.toString(),
        source: source,
        confidence: confidence,
        explanation: 'Record count from the income tool result.',
      ),
    );
  }

  void _mapExpenses(
    FinancialToolResult? result, {
    required List<AiCfoEvidence> recentLedgerSignals,
    required List<String> notes,
    required bool noteMissingSource,
  }) {
    final data = _dataMap(
      result,
      'Expense ledger records',
      notes,
      noteMissingSource: noteMissingSource,
    );
    if (data == null) return;
    const source = 'FinancialTools.getExpenses';
    final count = _toInt(data['count']);
    final confidence =
        count > 0 ? AiCfoEvidenceConfidence.high : AiCfoEvidenceConfidence.low;
    if (count == 0) {
      notes.add('Expense tool returned no ledger expense records.');
    }
    recentLedgerSignals.addAll([
      _evidence(
        label: 'Expense ledger rows',
        value: count.toString(),
        source: source,
        confidence: confidence,
        explanation: 'Count returned by the expense ledger tool.',
      ),
      _evidence(
        label: 'Expense total',
        value: _money(data['total']),
        source: source,
        confidence: confidence,
        explanation: 'Sum of expense ledger rows returned by the tool.',
      ),
    ]);
  }

  void _mapInvoices(
    FinancialToolResult? result, {
    required List<AiCfoEvidence> cashSummary,
    required List<AiCfoEvidence> receivablesSummary,
    required List<String> notes,
    required bool noteMissingSource,
  }) {
    final data = _dataMap(
      result,
      'Invoice records',
      notes,
      noteMissingSource: noteMissingSource,
    );
    if (data == null) return;
    const source = 'FinancialTools.getInvoices';
    final count = _toInt(data['count']);
    final confidence =
        count > 0 ? AiCfoEvidenceConfidence.high : AiCfoEvidenceConfidence.low;
    if (count == 0) {
      notes.add('Invoice tool returned no invoice records.');
    }
    cashSummary.add(
      _evidence(
        label: 'Invoice outstanding',
        value: _money(data['outstanding']),
        source: source,
        confidence: confidence,
        explanation: 'Outstanding invoice amount returned by the invoice tool.',
      ),
    );
    receivablesSummary.addAll([
      _evidence(
        label: 'Invoice count',
        value: count.toString(),
        source: source,
        confidence: confidence,
        explanation: 'Count returned by the invoice tool.',
      ),
      _evidence(
        label: 'Invoice outstanding',
        value: _money(data['outstanding']),
        source: source,
        confidence: confidence,
        explanation: 'Invoice total less paid amount returned by the tool.',
      ),
    ]);
  }

  void _mapCustomers(
    FinancialToolResult? result, {
    required List<AiCfoEvidence> receivablesSummary,
    required List<String> notes,
    required bool noteMissingSource,
  }) {
    final data = _dataMap(
      result,
      'Customer records',
      notes,
      noteMissingSource: noteMissingSource,
    );
    if (data == null) return;
    const source = 'FinancialTools.getCustomers';
    final count = _toInt(data['count']);
    final confidence =
        count > 0 ? AiCfoEvidenceConfidence.high : AiCfoEvidenceConfidence.low;
    if (count == 0) {
      notes.add('Customer tool returned no customer records.');
    }
    receivablesSummary.addAll([
      _evidence(
        label: 'Customer count',
        value: count.toString(),
        source: source,
        confidence: confidence,
        explanation: 'Count returned by the customer tool.',
      ),
      _evidence(
        label: 'Customer outstanding balance',
        value: _money(data['totalOutstanding']),
        source: source,
        confidence: confidence,
        explanation:
            'Total outstanding customer balance returned by the customer tool.',
      ),
    ]);
  }

  void _mapProducts(
    FinancialToolResult? result, {
    required List<AiCfoEvidence> inventorySummary,
    required List<String> notes,
    required bool noteMissingSource,
  }) {
    final data = _dataMap(
      result,
      'Product records',
      notes,
      noteMissingSource: noteMissingSource,
    );
    if (data == null) return;
    const source = 'FinancialTools.getProducts';
    final count = _toInt(data['count']);
    final confidence =
        count > 0 ? AiCfoEvidenceConfidence.high : AiCfoEvidenceConfidence.low;
    if (count == 0) {
      notes.add('Product tool returned no product records.');
    }
    inventorySummary.addAll([
      _evidence(
        label: 'Product count',
        value: count.toString(),
        source: source,
        confidence: confidence,
        explanation: 'Count returned by the product tool.',
      ),
      _evidence(
        label: 'Inventory value',
        value: _money(data['totalValue']),
        source: source,
        confidence: confidence,
        explanation:
            'Inventory value calculated by the existing product tool from stock and cost fields.',
      ),
    ]);
  }

  Map<String, dynamic>? _dataMap(
    FinancialToolResult? result,
    String label,
    List<String> notes, {
    required bool noteMissingSource,
  }) {
    if (result == null) {
      if (noteMissingSource) {
        notes.add('$label source was not requested for this intent.');
      }
      return null;
    }
    if (!result.success) {
      notes.add('$label unavailable: ${result.error ?? 'unknown error'}.');
      return null;
    }
    final data = result.data;
    if (data is! Map) {
      notes.add('$label returned no structured data.');
      return null;
    }
    return Map<String, dynamic>.from(data);
  }

  AiCfoEvidence _evidence({
    required String label,
    required String value,
    required String source,
    required AiCfoEvidenceConfidence confidence,
    required String explanation,
  }) {
    return AiCfoEvidence(
      label: label,
      value: value,
      source: source,
      confidence: confidence,
      explanation: explanation,
    );
  }

  String _money(dynamic value) => _toDouble(value).toStringAsFixed(2);

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
