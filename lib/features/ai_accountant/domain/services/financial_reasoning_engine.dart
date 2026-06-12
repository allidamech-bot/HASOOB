import 'ai_evidence_bundle.dart';
import 'ai_tool_planner.dart';

class FinancialReasoningEngine {
  String buildGroundedResponse({
    required AiToolPlan plan,
    required AiEvidenceBundle evidence,
  }) {
    switch (plan.intent) {
      case AiAccountantIntent.financialOverview:
        return _financialOverview(evidence);
      case AiAccountantIntent.profitabilityAnalysis:
        return _profitability(evidence);
      case AiAccountantIntent.inventoryAnalysis:
        return _inventory(evidence);
      case AiAccountantIntent.customerBalanceAnalysis:
        return _customerBalances(evidence);
      case AiAccountantIntent.cashFlowAnalysis:
        return _cashFlow(evidence);
      case AiAccountantIntent.invoiceAnalysis:
        return _invoice(evidence);
      case AiAccountantIntent.purchasePreparation:
        return 'To prepare a purchase proposal safely, I need product, quantity, unit cost or total cost, and supplier/payment info. Once those are clear, I can prepare a reviewable proposal card. I will not record anything until you approve it.';
      case AiAccountantIntent.salePreparation:
        return 'To prepare a sale proposal safely, I need product, quantity, selling price, customer, and payment terms. Once those are clear, I can prepare a reviewable proposal card. I will not record anything until you approve it.';
      case AiAccountantIntent.executionIntent:
        return 'I need a clear proposal before execution. Do you want to prepare a purchase, sale, or pricing simulation?';
      case AiAccountantIntent.pricingDecision:
      case AiAccountantIntent.exportDecision:
      case AiAccountantIntent.generalAdvice:
      case AiAccountantIntent.unknown:
        return _advisoryOnly(plan);
    }
  }

  String _financialOverview(AiEvidenceBundle evidence) {
    final summary = _summary(evidence, 'getFinancialSummary');
    final invoices = _summary(evidence, 'getInvoices');
    final products = _summary(evidence, 'getProducts');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence,
          checked: 'financial summary, invoices, and inventory');
    }
    return [
      'What I checked: financial summary, invoices, and inventory.',
      'What I found: income ${_value(summary, 'totalIncome')}, expenses ${_value(summary, 'totalExpenses')}, profit ${_value(summary, 'totalProfit')}, receivables ${_value(summary, 'accountsReceivable')}, invoices ${_value(invoices, 'count')}, low-stock records ${_value(products, 'count')}.',
      'Risk: watch receivables and stock exposure before committing to new purchases.',
      'Recommendation: review cash collection first, then decide whether growth should come from faster-moving stock or improved margin.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _profitability(AiEvidenceBundle evidence) {
    final income = _summary(evidence, 'getIncome');
    final expenses = _summary(evidence, 'getExpenses');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence, checked: 'income and expenses');
    }
    return [
      'What I checked: income records and expense records.',
      'What I found: sales total ${_value(income, 'total')}, recorded gross profit ${_value(income, 'profit')}, expense total ${_value(expenses, 'total')}.',
      'Risk: profitability can look stronger than cash if receivables are slow or costs are missing from expense records.',
      'Recommendation: compare gross profit against operating expenses before changing prices.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _inventory(AiEvidenceBundle evidence) {
    final products = _summary(evidence, 'getProducts');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence, checked: 'inventory/products');
    }
    return [
      'What I checked: product and inventory records.',
      'What I found: product count ${_value(products, 'count')}, estimated inventory value ${_value(products, 'totalValue')}.',
      'Risk: inventory risk can be stockout, slow movement, or cash tied up in stock.',
      'Recommendation: separate low-stock items from slow-moving items before preparing a purchase.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _customerBalances(AiEvidenceBundle evidence) {
    final customers = _summary(evidence, 'getCustomers');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence, checked: 'customer balances');
    }
    return [
      'What I checked: customer balance records.',
      'What I found: customer count ${_value(customers, 'count')}, outstanding balance ${_value(customers, 'totalOutstanding')}.',
      'Risk: high receivables can weaken cash even when sales look healthy.',
      'Recommendation: prioritize collection terms before extending more credit.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _cashFlow(AiEvidenceBundle evidence) {
    final summary = _summary(evidence, 'getFinancialSummary');
    final invoices = _summary(evidence, 'getInvoices');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence,
          checked: 'financial summary and invoices');
    }
    return [
      'What I checked: financial summary and invoices.',
      'What I found: net cash flow ${_value(summary, 'netCashFlow')}, receivables ${_value(summary, 'accountsReceivable')}, invoice outstanding ${_value(invoices, 'outstanding')}.',
      'Risk: cash pressure usually comes from slow collection or upcoming purchases landing before invoices are paid.',
      'Recommendation: review due invoices before approving new stock commitments.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _invoice(AiEvidenceBundle evidence) {
    final invoices = _summary(evidence, 'getInvoices');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence, checked: 'invoices');
    }
    return [
      'What I checked: invoice records.',
      'What I found: invoice count ${_value(invoices, 'count')}, total ${_value(invoices, 'totalAmount')}, paid ${_value(invoices, 'totalPaid')}, outstanding ${_value(invoices, 'outstanding')}.',
      'Risk: unpaid invoices reduce cash flexibility.',
      'Recommendation: sort invoices by age and collection probability before planning purchases.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _advisoryOnly(AiToolPlan plan) {
    if (plan.missingInputs.isEmpty) {
      return 'I can advise, but I do not have enough confirmed data to calculate that yet. Share the relevant numbers or ask me to check available system data.';
    }
    return 'I do not have enough confirmed data to calculate that yet.\nMissing information: ${plan.missingInputs.join(', ')}.\nRecommendation: provide those inputs first, then I can compare the decision safely.';
  }

  String _notEnoughData(AiEvidenceBundle evidence, {required String checked}) {
    return [
      'What I checked: $checked.',
      'What I found: I do not have enough confirmed data to calculate that yet.',
      'Risk: making a decision from incomplete records can overstate profit or cash availability.',
      'Recommendation: provide the missing inputs or confirm the records are available.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  Map<String, dynamic> _summary(AiEvidenceBundle evidence, String toolName) {
    final value = evidence.summaries[toolName];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _value(Map<String, dynamic> summary, String key) {
    final value = summary[key];
    if (value == null) return 'not available';
    if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    return value.toString();
  }

  String _missingLine(AiEvidenceBundle evidence) {
    if (evidence.missingEvidence.isEmpty) return '';
    return 'Missing information: ${evidence.missingEvidence.join(', ')}.';
  }
}
