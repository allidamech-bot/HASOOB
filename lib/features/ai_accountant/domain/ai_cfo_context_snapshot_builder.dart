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
    _addMoneyEvidence(
      data,
      key: 'netCashFlow',
      label: 'Net cash flow',
      source: source,
      confidence: AiCfoEvidenceConfidence.medium,
      explanation:
          'Derived from income and expense totals returned by the financial summary tool.',
      target: cashSummary,
      notes: notes,
    );
    _addMoneyEvidence(
      data,
      key: 'accountsReceivable',
      label: 'Accounts receivable',
      source: source,
      confidence: AiCfoEvidenceConfidence.medium,
      explanation:
          'Derived from invoice outstanding balances in the financial summary tool.',
      target: cashSummary,
      notes: notes,
    );
    _addMoneyEvidence(
      data,
      key: 'totalIncome',
      label: 'Total income',
      source: source,
      confidence: AiCfoEvidenceConfidence.medium,
      explanation: 'Read from the financial summary tool.',
      target: salesSummary,
      notes: notes,
    );
    _addMoneyEvidence(
      data,
      key: 'totalProfit',
      label: 'Total profit',
      source: source,
      confidence: AiCfoEvidenceConfidence.medium,
      explanation: 'Read from the financial summary tool.',
      target: salesSummary,
      notes: notes,
    );
    _addNumberEvidence(
      data,
      key: 'profitMargin',
      label: 'Profit margin',
      source: source,
      confidence: AiCfoEvidenceConfidence.medium,
      explanation:
          'Calculated by the existing financial summary tool from income and profit.',
      target: salesSummary,
      notes: notes,
      suffix: '%',
      decimals: 1,
    );
    _addMoneyEvidence(
      data,
      key: 'accountsReceivable',
      label: 'Accounts receivable',
      source: source,
      confidence: AiCfoEvidenceConfidence.medium,
      explanation:
          'Derived from invoice outstanding balances in the financial summary tool.',
      target: receivablesSummary,
      notes: notes,
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
    final count = _intIfPresent(data, 'count', 'Sales record count', notes);
    final confidence = _countConfidence(count);
    if (count == 0) {
      notes.add('Income tool returned no sales records.');
    }
    if (count != null) {
      salesSummary.add(
        _evidence(
          label: 'Sales record count',
          value: count.toString(),
          source: source,
          confidence: confidence,
          explanation: 'Count returned by the income tool.',
        ),
      );
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
    _addMoneyEvidence(
      data,
      key: 'total',
      label: 'Sales total',
      source: source,
      confidence: confidence,
      explanation: 'Sum of sales records returned by the income tool.',
      target: salesSummary,
      notes: notes,
    );
    _addMoneyEvidence(
      data,
      key: 'profit',
      label: 'Gross profit',
      source: source,
      confidence: confidence,
      explanation: 'Sum of profit values returned by the income tool.',
      target: salesSummary,
      notes: notes,
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
    final count = _intIfPresent(data, 'count', 'Expense ledger rows', notes);
    final confidence = _countConfidence(count);
    if (count == 0) {
      notes.add('Expense tool returned no ledger expense records.');
    }
    if (count != null) {
      recentLedgerSignals.add(
        _evidence(
          label: 'Expense ledger rows',
          value: count.toString(),
          source: source,
          confidence: confidence,
          explanation: 'Count returned by the expense ledger tool.',
        ),
      );
    }
    _addMoneyEvidence(
      data,
      key: 'total',
      label: 'Expense total',
      source: source,
      confidence: confidence,
      explanation: 'Sum of expense ledger rows returned by the tool.',
      target: recentLedgerSignals,
      notes: notes,
    );
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
    final count = _intIfPresent(data, 'count', 'Invoice count', notes);
    final confidence = _countConfidence(count);
    if (count == 0) {
      notes.add('Invoice tool returned no invoice records.');
    }
    _addMoneyEvidence(
      data,
      key: 'outstanding',
      label: 'Invoice outstanding',
      source: source,
      confidence: confidence,
      explanation: 'Outstanding invoice amount returned by the invoice tool.',
      target: cashSummary,
      notes: notes,
    );
    if (count != null) {
      receivablesSummary.add(
        _evidence(
          label: 'Invoice count',
          value: count.toString(),
          source: source,
          confidence: confidence,
          explanation: 'Count returned by the invoice tool.',
        ),
      );
    }
    _addMoneyEvidence(
      data,
      key: 'outstanding',
      label: 'Invoice outstanding',
      source: source,
      confidence: confidence,
      explanation: 'Invoice total less paid amount returned by the tool.',
      target: receivablesSummary,
      notes: notes,
    );
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
    final count = _intIfPresent(data, 'count', 'Customer count', notes);
    final confidence = _countConfidence(count);
    if (count == 0) {
      notes.add('Customer tool returned no customer records.');
    }
    if (count != null) {
      receivablesSummary.add(
        _evidence(
          label: 'Customer count',
          value: count.toString(),
          source: source,
          confidence: confidence,
          explanation: 'Count returned by the customer tool.',
        ),
      );
    }
    _addMoneyEvidence(
      data,
      key: 'totalOutstanding',
      label: 'Customer outstanding balance',
      source: source,
      confidence: confidence,
      explanation:
          'Total outstanding customer balance returned by the customer tool.',
      target: receivablesSummary,
      notes: notes,
    );
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
    final count = _intIfPresent(data, 'count', 'Product count', notes);
    final confidence = _countConfidence(count);
    if (count == 0) {
      notes.add('Product tool returned no product records.');
    }
    if (count != null) {
      inventorySummary.add(
        _evidence(
          label: 'Product count',
          value: count.toString(),
          source: source,
          confidence: confidence,
          explanation: 'Count returned by the product tool.',
        ),
      );
    }
    _addMoneyEvidence(
      data,
      key: 'totalValue',
      label: 'Inventory value',
      source: source,
      confidence: confidence,
      explanation:
          'Inventory value calculated by the existing product tool from stock and cost fields.',
      target: inventorySummary,
      notes: notes,
    );
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

  void _addMoneyEvidence(
    Map<String, dynamic> data, {
    required String key,
    required String label,
    required String source,
    required AiCfoEvidenceConfidence confidence,
    required String explanation,
    required List<AiCfoEvidence> target,
    required List<String> notes,
  }) {
    final value = _moneyIfPresent(data, key, label, notes);
    if (value == null) return;
    target.add(
      _evidence(
        label: label,
        value: value,
        source: source,
        confidence: confidence,
        explanation: explanation,
      ),
    );
  }

  void _addNumberEvidence(
    Map<String, dynamic> data, {
    required String key,
    required String label,
    required String source,
    required AiCfoEvidenceConfidence confidence,
    required String explanation,
    required List<AiCfoEvidence> target,
    required List<String> notes,
    String suffix = '',
    int decimals = 0,
  }) {
    final value = _numberIfPresent(
      data,
      key,
      label,
      notes,
      suffix: suffix,
      decimals: decimals,
    );
    if (value == null) return;
    target.add(
      _evidence(
        label: label,
        value: value,
        source: source,
        confidence: confidence,
        explanation: explanation,
      ),
    );
  }

  bool _hasValue(Map<String, dynamic> data, String key) {
    return data.containsKey(key) && data[key] != null;
  }

  String? _moneyIfPresent(
    Map<String, dynamic> data,
    String key,
    String label,
    List<String> notes,
  ) {
    if (!_hasValue(data, key)) {
      _addMissingFieldNote(label, key, notes);
      return null;
    }
    return _toDouble(data[key]).toStringAsFixed(2);
  }

  String? _numberIfPresent(
    Map<String, dynamic> data,
    String key,
    String label,
    List<String> notes, {
    String suffix = '',
    int decimals = 0,
  }) {
    if (!_hasValue(data, key)) {
      _addMissingFieldNote(label, key, notes);
      return null;
    }
    return '${_toDouble(data[key]).toStringAsFixed(decimals)}$suffix';
  }

  int? _intIfPresent(
    Map<String, dynamic> data,
    String key,
    String label,
    List<String> notes,
  ) {
    if (!_hasValue(data, key)) {
      _addMissingFieldNote(label, key, notes);
      return null;
    }
    return _toInt(data[key]);
  }

  void _addMissingFieldNote(String label, String key, List<String> notes) {
    notes.add('$label missing source field "$key".');
  }

  AiCfoEvidenceConfidence _countConfidence(int? count) {
    if (count == null || count == 0) return AiCfoEvidenceConfidence.low;
    return AiCfoEvidenceConfidence.high;
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
