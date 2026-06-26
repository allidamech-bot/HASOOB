import 'ai_evidence_bundle.dart';
import 'ai_customer_credit_intelligence.dart';
import 'ai_executive_cfo_autonomy.dart';
import 'ai_financial_snapshot.dart';
import 'ai_insight_generator.dart';
import 'ai_risk_detector.dart';
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
        return 'Good. To prepare this purchase properly, I need a few things from you:\n\n1. Product name and quantity\n2. Unit cost or total cost\n3. Supplier name\n4. Payment terms (cash now, credit, installments?)\n\nOnce you give me these, I will prepare a reviewable proposal card. Nothing is recorded until you review and explicitly approve it.';
      case AiAccountantIntent.salePreparation:
        return 'Understood. To prepare this sale properly, I need:\n\n1. Product name and quantity\n2. Selling price per unit\n3. Customer name\n4. Payment terms (cash, credit, due date?)\n\nOnce confirmed, I will prepare a reviewable proposal. Nothing is recorded until you approve it.';
      case AiAccountantIntent.executionIntent:
        return 'I want to make sure we do this correctly. I need a clear, complete proposal before anything is recorded. Would you like to prepare a purchase, a sale, or run a pricing simulation first?';
      case AiAccountantIntent.pricingDecision:
      case AiAccountantIntent.exportDecision:
      case AiAccountantIntent.generalAdvice:
      case AiAccountantIntent.unknown:
        return _advisoryOnly(plan);
    }
  }

  String _financialOverview(AiEvidenceBundle evidence) {
    final snapshot = AiFinancialSnapshot.fromEvidence(evidence);
    final risks = AiRiskDetector().detect(snapshot);
    final generator = AiInsightGenerator();
    final recommendations = generator.generateRecommendations(
      snapshot: snapshot,
      risks: risks,
    );
    final briefing = AiExecutiveCfoAutonomy().generateBriefing(
      snapshot: snapshot,
      evidence: evidence,
      risks: risks,
      recommendations: recommendations,
    );
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence,
          checked: 'financial summary, invoices, inventory, and customers');
    }
    return [
      'Business Overview',
      'What I checked: financial summary, invoices, inventory, and customer balances.',
      'What I found: revenue ${_format(snapshot.revenue)}, expenses ${_format(snapshot.expenses)}, profit ${_format(snapshot.profit)}, pending invoices ${_format(snapshot.pendingInvoices)}, overdue invoices ${snapshot.overdueInvoices ?? 'not available'}, inventory health ${snapshot.inventoryHealth ?? 'not available'}, customer risk ${snapshot.customerRisk ?? 'not available'}.',
      'Risks: ${risks.map((risk) => '${risk.levelLabel} - ${risk.title}: ${risk.description}').join(' ')}',
      'Recommendations: ${recommendations.map((item) => '${item.title}: ${item.description}').join(' ')}',
      'Executive Briefing: ${briefing.businessHealthSummary} Cash status: ${briefing.cashStatus} Urgent decisions: ${briefing.urgentDecisionsRequired.join(' | ')} Confidence score: ${briefing.confidenceScore}.',
      'Decision Packs: ${briefing.recommendedExecutiveActions.map((pack) => '${pack.riskLabel} - ${pack.summary}: ${pack.recommendedNextStep}').join(' ')}',
      'Next Actions: collect overdue balances first, review low-stock items, then decide whether to improve margin or prepare a guarded proposal.',
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
    final report = AiCustomerCreditIntelligence().analyze(evidence);
    final top = report.riskiestCustomer;
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(
        evidence,
        checked: 'customer balances and invoice payment history',
      );
    }
    if (top == null) {
      return [
        'Customer Credit Intelligence',
        'What I checked: customer balances and invoice payment history.',
        'What I found: no customer records were available for credit scoring.',
        'Scoring Model: ${report.scoringModel}',
        _missingLine(evidence),
      ].where((line) => line.isNotEmpty).join('\n');
    }
    final watchlist = report.customers.take(3).map((customer) {
      return '${customer.customerName}: ${customer.riskScore}/100, ${customer.riskLabel}, outstanding ${_format(customer.outstandingBalance)}, overdue ${customer.overdueCount}/${customer.invoiceCount}.';
    }).join(' ');
    return [
      'Customer Credit Intelligence',
      'Scoring Model: ${report.scoringModel}',
      'Highest Risk Customer: ${top.customerName} - ${top.riskScore}/100 (${top.riskLabel}).',
      'Explanation: ${top.explanation}',
      'Evidence: ${top.evidence.join('; ')}.',
      'Confidence: ${top.confidence.name.toUpperCase()} from ${report.evidenceSources.join('; ')}.',
      'Recommended Action: ${top.recommendedAction}',
      'Watchlist: $watchlist',
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
      'Cash Flow Analysis',
      '',
      'What I understand: you want to know the real cash position — not just profit on paper.',
      '',
      'What I found in your records:',
      '• Net cash flow: ${_value(summary, 'netCashFlow')}',
      '• Receivables (cash owed to you): ${_value(summary, 'accountsReceivable')}',
      '• Invoice outstanding: ${_value(invoices, 'outstanding')}',
      '',
      'Accounting meaning: cash pressure usually comes from two places — slow invoice collection and purchases arriving before you have collected what customers owe you.',
      '',
      'Risk: if your outstanding invoices are high relative to cash on hand, you are exposed to a liquidity gap.',
      '',
      'Recommended next step: review the oldest unpaid invoices first, then decide whether you can safely commit to new purchases.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _invoice(AiEvidenceBundle evidence) {
    final invoices = _summary(evidence, 'getInvoices');
    if (evidence.confidenceLevel == AiEvidenceConfidence.low) {
      return _notEnoughData(evidence, checked: 'invoices');
    }
    return [
      'Invoice / Receivables Review',
      '',
      'What I found in your invoice records:',
      '• Invoice count: ${_value(invoices, 'count')}',
      '• Total invoiced: ${_value(invoices, 'totalAmount')}',
      '• Total collected: ${_value(invoices, 'totalPaid')}',
      '• Still outstanding: ${_value(invoices, 'outstanding')}',
      '',
      'Accounting meaning: outstanding invoices are receivables on your balance sheet. They represent real value, but only when collected.',
      '',
      'Risk: unpaid invoices reduce your actual cash flexibility even if profit looks good.',
      '',
      'Recommended next step: sort invoices by age. Focus collection efforts on the oldest balances first. Consider whether any are overdue enough to require a formal follow-up.',
      _missingLine(evidence),
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String _advisoryOnly(AiToolPlan plan) {
    if (plan.missingInputs.isEmpty) {
      return 'I understand what you are asking. Let me be direct with you: I do not have enough confirmed figures from your records to give you a reliable answer right now.\n\nTo help you properly, I need you to either share the relevant numbers directly in the chat, or add the data to HASOOB so I can pull it from your actual records.\n\nWhat specific number or situation would you like to work through?';
    }
    return 'I understand the question, but I am missing some key information before I can give you a reliable answer.\n\nMissing: ${plan.missingInputs.join(', ')}.\n\nProvide these and I can give you a proper analysis with the accounting implications and recommended next steps.';
  }

  String _notEnoughData(AiEvidenceBundle evidence, {required String checked}) {
    final missing = _missingLine(evidence);
    return [
      'I checked $checked in your records.',
      '',
      'Honest assessment: the data available is not enough for me to give you a reliable figure. I will not estimate or guess — that would be worse than no answer.',
      '',
      'The risk of acting on incomplete records is that it can overstate profit, understate costs, or hide cash pressure.',
      '',
      if (missing.isNotEmpty) missing,
      '',
      'What to do next: add the missing records to HASOOB, or tell me the numbers directly and I will work through the analysis with you.',
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

  String _format(num? value) {
    if (value == null) return 'not available';
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  String _missingLine(AiEvidenceBundle evidence) {
    if (evidence.missingEvidence.isEmpty) return '';
    return 'Missing information: ${evidence.missingEvidence.join(', ')}.';
  }
}
