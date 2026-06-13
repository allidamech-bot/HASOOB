import 'ai_business_memory.dart';
import 'ai_customer_credit_intelligence.dart';
import 'ai_evidence_bundle.dart';
import 'ai_financial_snapshot.dart';
import 'ai_import_export_cfo_advisor.dart';
import 'ai_insight_generator.dart';
import 'ai_risk_detector.dart';

enum AiExecutiveRiskType {
  fallingCashReserves,
  customerConcentration,
  overdueCustomer,
  inventoryOverbuying,
  inventoryShortage,
  importExportShipment,
  unusualExpenseGrowth,
  profitabilityDecline,
}

class AiExecutiveRiskAlert {
  final AiExecutiveRiskType type;
  final AiFinancialRiskLevel level;
  final String summary;
  final String explanation;
  final List<String> evidence;
  final AiEvidenceConfidence confidence;

  const AiExecutiveRiskAlert({
    required this.type,
    required this.level,
    required this.summary,
    required this.explanation,
    required this.evidence,
    required this.confidence,
  });

  String get levelLabel => level.name.toUpperCase();
}

class AiExecutiveDecisionPack {
  final String summary;
  final String reasoning;
  final List<String> evidence;
  final AiEvidenceConfidence confidence;
  final String expectedFinancialImpact;
  final AiFinancialRiskLevel riskLevel;
  final List<String> actionOptions;
  final String recommendedNextStep;
  final bool requiresApproval;

  const AiExecutiveDecisionPack({
    required this.summary,
    required this.reasoning,
    required this.evidence,
    required this.confidence,
    required this.expectedFinancialImpact,
    required this.riskLevel,
    required this.actionOptions,
    required this.recommendedNextStep,
    this.requiresApproval = true,
  });

  String get riskLabel => riskLevel.name.toUpperCase();
}

class AiExecutiveBriefing {
  final String businessHealthSummary;
  final String cashStatus;
  final List<AiExecutiveRiskAlert> topRisks;
  final List<String> topOpportunities;
  final List<String> urgentDecisionsRequired;
  final List<AiExecutiveDecisionPack> recommendedExecutiveActions;
  final AiEvidenceConfidence confidence;
  final List<String> evidenceReferences;
  final List<String> memoryContext;

  const AiExecutiveBriefing({
    required this.businessHealthSummary,
    required this.cashStatus,
    required this.topRisks,
    required this.topOpportunities,
    required this.urgentDecisionsRequired,
    required this.recommendedExecutiveActions,
    required this.confidence,
    required this.evidenceReferences,
    this.memoryContext = const [],
  });

  int get confidenceScore {
    switch (confidence) {
      case AiEvidenceConfidence.high:
        return 90;
      case AiEvidenceConfidence.medium:
        return 65;
      case AiEvidenceConfidence.low:
        return 35;
    }
  }
}

class AiExecutiveCfoAutonomy {
  AiExecutiveBriefing generateBriefing({
    required AiFinancialSnapshot snapshot,
    required AiEvidenceBundle evidence,
    List<AiFinancialRisk> risks = const [],
    List<AiFinancialRecommendation> recommendations = const [],
    AiCustomerCreditReport? customerCredit,
    AiShipmentDecisionResult? shipmentDecision,
    List<AiCfoMemoryItem> memories = const [],
  }) {
    final alerts = monitorRisks(
      snapshot: snapshot,
      evidence: evidence,
      risks: risks,
      customerCredit: customerCredit,
      shipmentDecision: shipmentDecision,
    );
    final packs = generateDecisionPacks(
      snapshot: snapshot,
      alerts: alerts,
      recommendations: recommendations,
      memories: memories,
    );

    return AiExecutiveBriefing(
      businessHealthSummary: _businessHealth(snapshot, alerts),
      cashStatus: _cashStatus(snapshot),
      topRisks: alerts.take(5).toList(),
      topOpportunities: _opportunities(snapshot, customerCredit),
      urgentDecisionsRequired: _urgentDecisions(alerts),
      recommendedExecutiveActions: packs,
      confidence: _briefingConfidence(snapshot, evidence, alerts),
      evidenceReferences: _evidenceReferences(evidence),
      memoryContext: memories.map(_memoryLine).take(3).toList(),
    );
  }

  List<AiExecutiveRiskAlert> monitorRisks({
    required AiFinancialSnapshot snapshot,
    required AiEvidenceBundle evidence,
    List<AiFinancialRisk> risks = const [],
    AiCustomerCreditReport? customerCredit,
    AiShipmentDecisionResult? shipmentDecision,
  }) {
    final alerts = <AiExecutiveRiskAlert>[];

    if ((snapshot.pendingInvoices ?? 0) > 0 ||
        risks.any((risk) => risk.title == 'Overdue invoices')) {
      alerts.add(AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.fallingCashReserves,
        level: AiFinancialRiskLevel.high,
        summary: 'Cash reserves may weaken if receivables are not collected.',
        explanation:
            'Pending invoices and overdue balances can delay cash conversion before new commitments.',
        evidence: [
          if (snapshot.pendingInvoices != null)
            'pending invoices ${snapshot.pendingInvoices!.toStringAsFixed(2)}',
          if (snapshot.overdueInvoices != null)
            'overdue invoices ${snapshot.overdueInvoices}',
        ],
        confidence: snapshot.confidence,
      ));
    }

    final riskiestCustomer = customerCredit?.riskiestCustomer;
    if (riskiestCustomer != null) {
      if (riskiestCustomer.concentrationRisk >= 0.5) {
        alerts.add(AiExecutiveRiskAlert(
          type: AiExecutiveRiskType.customerConcentration,
          level: AiFinancialRiskLevel.high,
          summary:
              '${riskiestCustomer.customerName} is a customer concentration risk.',
          explanation:
              'One customer represents ${(riskiestCustomer.concentrationRisk * 100).toStringAsFixed(1)}% of open customer exposure.',
          evidence: riskiestCustomer.evidence,
          confidence: riskiestCustomer.confidence,
        ));
      }
      if (riskiestCustomer.overdueCount > 0) {
        alerts.add(AiExecutiveRiskAlert(
          type: AiExecutiveRiskType.overdueCustomer,
          level: AiFinancialRiskLevel.high,
          summary:
              '${riskiestCustomer.customerName} has overdue customer risk.',
          explanation:
              'This customer has ${riskiestCustomer.overdueCount} overdue invoice(s) and should be collected before more credit.',
          evidence: riskiestCustomer.evidence,
          confidence: riskiestCustomer.confidence,
        ));
      }
    }

    if ((snapshot.lowStockProducts ?? 0) > 0) {
      alerts.add(AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.inventoryShortage,
        level: AiFinancialRiskLevel.medium,
        summary: 'Inventory shortage risk is visible.',
        explanation:
            '${snapshot.lowStockProducts} product(s) are at or below threshold.',
        evidence: ['low stock products ${snapshot.lowStockProducts}'],
        confidence: snapshot.confidence,
      ));
    }

    if ((snapshot.pendingInvoices ?? 0) > 0 &&
        (snapshot.lowStockProducts ?? 0) > 0) {
      alerts.add(AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.inventoryOverbuying,
        level: AiFinancialRiskLevel.medium,
        summary: 'Inventory purchase should be controlled against cash timing.',
        explanation:
            'Open receivables plus stock pressure can create overbuying risk if purchases are approved before collections.',
        evidence: [
          'pending invoices ${snapshot.pendingInvoices!.toStringAsFixed(2)}',
          'low stock products ${snapshot.lowStockProducts}',
        ],
        confidence: snapshot.confidence,
      ));
    }

    if (shipmentDecision != null &&
        shipmentDecision.recommendation != AiTradeRecommendation.proceed) {
      alerts.add(AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.importExportShipment,
        level: shipmentDecision.riskLevel == AiTradeRiskLevel.medium
            ? AiFinancialRiskLevel.medium
            : AiFinancialRiskLevel.high,
        summary: 'Import/export shipment risk requires executive review.',
        explanation:
            'Shipment action is ${shipmentDecision.recommendedAction} with margin ${shipmentDecision.marginPercent.toStringAsFixed(2)}%.',
        evidence: shipmentDecision.evidence,
        confidence: shipmentDecision.confidence,
      ));
    }

    final revenue = snapshot.revenue ?? 0;
    final expenses = snapshot.expenses ?? 0;
    final profit = snapshot.profit ?? 0;
    if (expenses > revenue && revenue > 0) {
      alerts.add(AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.unusualExpenseGrowth,
        level: AiFinancialRiskLevel.high,
        summary: 'Expense growth is unusual against revenue.',
        explanation:
            'Expenses ${expenses.toStringAsFixed(2)} exceed revenue ${revenue.toStringAsFixed(2)}.',
        evidence: [
          'revenue ${revenue.toStringAsFixed(2)}',
          'expenses ${expenses.toStringAsFixed(2)}',
        ],
        confidence: snapshot.confidence,
      ));
    }

    if (profit < 0) {
      alerts.add(AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.profitabilityDecline,
        level: AiFinancialRiskLevel.high,
        summary: 'Profitability decline detected.',
        explanation:
            'Profit is negative at ${profit.toStringAsFixed(2)} in the available snapshot.',
        evidence: ['profit ${profit.toStringAsFixed(2)}'],
        confidence: snapshot.confidence,
      ));
    }

    alerts.sort((a, b) => _riskRank(b.level).compareTo(_riskRank(a.level)));
    return alerts;
  }

  List<AiExecutiveDecisionPack> generateDecisionPacks({
    required AiFinancialSnapshot snapshot,
    required List<AiExecutiveRiskAlert> alerts,
    List<AiFinancialRecommendation> recommendations = const [],
    List<AiCfoMemoryItem> memories = const [],
  }) {
    final packs = <AiExecutiveDecisionPack>[];
    for (final alert in alerts) {
      packs.add(_packForAlert(alert, memories));
    }
    for (final recommendation in recommendations) {
      if (recommendation.title == 'Keep monitoring') continue;
      packs.add(AiExecutiveDecisionPack(
        summary: recommendation.title,
        reasoning: _memorySupportedReasoning(
          recommendation.description,
          memories,
        ),
        evidence: [
          recommendation.description,
          if (snapshot.profit != null)
            'profit ${snapshot.profit!.toStringAsFixed(2)}',
        ],
        confidence: snapshot.confidence,
        expectedFinancialImpact:
            'Improves control over cash, margin, or operating exposure before execution.',
        riskLevel: AiFinancialRiskLevel.medium,
        actionOptions: const [
          'Review proposal',
          'Ask for more evidence',
          'Defer action',
        ],
        recommendedNextStep:
            'Prepare or review through the existing guarded proposal workflow.',
      ));
    }
    return _dedupePacks(packs).take(6).toList();
  }

  AiExecutiveDecisionPack _packForAlert(
    AiExecutiveRiskAlert alert,
    List<AiCfoMemoryItem> memories,
  ) {
    final recommendation = switch (alert.type) {
      AiExecutiveRiskType.fallingCashReserves =>
        'Postpone non-critical expense and collect overdue receivables first.',
      AiExecutiveRiskType.customerConcentration =>
        'Reduce exposure to the risky customer before approving new credit.',
      AiExecutiveRiskType.overdueCustomer =>
        'Collect from high-risk customer before approving new credit.',
      AiExecutiveRiskType.inventoryOverbuying =>
        'Delay inventory purchase until cash timing is safer.',
      AiExecutiveRiskType.inventoryShortage =>
        'Prioritize profitable product replenishment through proposal review.',
      AiExecutiveRiskType.importExportShipment =>
        'Renegotiate shipment terms before committing.',
      AiExecutiveRiskType.unusualExpenseGrowth =>
        'Postpone non-critical expense and review cost categories.',
      AiExecutiveRiskType.profitabilityDecline =>
        'Increase price to protect margin or reduce loss-making commitments.',
    };

    return AiExecutiveDecisionPack(
      summary: recommendation,
      reasoning: _memorySupportedReasoning(alert.explanation, memories),
      evidence: alert.evidence,
      confidence: alert.confidence,
      expectedFinancialImpact: _impactFor(alert.type),
      riskLevel: alert.level,
      actionOptions: const [
        'Approve proposal review only',
        'Request more evidence',
        'Defer execution',
      ],
      recommendedNextStep:
          'Keep this advisory and route any executable action through proposal/workflow approval.',
    );
  }

  String _businessHealth(
    AiFinancialSnapshot snapshot,
    List<AiExecutiveRiskAlert> alerts,
  ) {
    final highRisks =
        alerts.where((risk) => risk.level == AiFinancialRiskLevel.high).length;
    final profit = snapshot.profit;
    if (highRisks >= 2 || (profit != null && profit < 0)) {
      return 'Business health needs executive attention.';
    }
    if (alerts.isNotEmpty) return 'Business health is stable but watchlisted.';
    return 'Business health is stable from available evidence.';
  }

  String _cashStatus(AiFinancialSnapshot snapshot) {
    final pending = snapshot.pendingInvoices;
    final overdue = snapshot.overdueInvoices;
    if ((pending ?? 0) <= 0) return 'No material receivables pressure found.';
    return 'Cash depends on collecting ${pending!.toStringAsFixed(2)} in pending invoices'
        '${overdue == null ? '' : ' with $overdue overdue invoice(s)'}.';
  }

  List<String> _opportunities(
    AiFinancialSnapshot snapshot,
    AiCustomerCreditReport? customerCredit,
  ) {
    return [
      if ((snapshot.profit ?? 0) > 0)
        'Prioritize profitable product/customer segments.',
      if ((snapshot.lowStockProducts ?? 0) > 0)
        'Replenish proven low-stock products after cash review.',
      if (customerCredit?.riskiestCustomer != null)
        'Improve collections discipline by focusing on largest exposure first.',
      if ((snapshot.profit ?? 0) <= 0 && snapshot.revenue != null)
        'Protect margin through price and cost review.',
    ];
  }

  List<String> _urgentDecisions(List<AiExecutiveRiskAlert> alerts) {
    return alerts.map((alert) => alert.summary).take(4).toList();
  }

  AiEvidenceConfidence _briefingConfidence(
    AiFinancialSnapshot snapshot,
    AiEvidenceBundle evidence,
    List<AiExecutiveRiskAlert> alerts,
  ) {
    if (snapshot.confidence == AiEvidenceConfidence.high &&
        evidence.confidenceLevel == AiEvidenceConfidence.high &&
        alerts.every((alert) => alert.confidence != AiEvidenceConfidence.low)) {
      return AiEvidenceConfidence.high;
    }
    if (snapshot.hasEvidence) return AiEvidenceConfidence.medium;
    return AiEvidenceConfidence.low;
  }

  List<String> _evidenceReferences(AiEvidenceBundle evidence) {
    return evidence.executedTools
        .where((tool) => tool.success)
        .map((tool) => '${tool.toolName}: ${tool.reason}')
        .toList();
  }

  String _memoryLine(AiCfoMemoryItem memory) {
    return '${memory.summary} (source: ${memory.source}, confidence: ${memory.confidence.name.toUpperCase()})';
  }

  String _memorySupportedReasoning(
    String reasoning,
    List<AiCfoMemoryItem> memories,
  ) {
    if (memories.isEmpty) return reasoning;
    return '$reasoning Memory support: ${memories.first.summary}';
  }

  String _impactFor(AiExecutiveRiskType type) {
    return switch (type) {
      AiExecutiveRiskType.fallingCashReserves =>
        'Protects cash reserves by improving collection timing before spend.',
      AiExecutiveRiskType.customerConcentration =>
        'Reduces receivables concentration and bad-debt exposure.',
      AiExecutiveRiskType.overdueCustomer =>
        'Improves cash conversion and limits new credit exposure.',
      AiExecutiveRiskType.inventoryOverbuying =>
        'Avoids tying cash in stock before receivables are collected.',
      AiExecutiveRiskType.inventoryShortage =>
        'Protects revenue by prioritizing stock with proven demand.',
      AiExecutiveRiskType.importExportShipment =>
        'Protects margin by improving freight, customs, or price terms.',
      AiExecutiveRiskType.unusualExpenseGrowth =>
        'Reduces avoidable cash outflow.',
      AiExecutiveRiskType.profitabilityDecline =>
        'Improves margin before additional commitments.',
    };
  }

  List<AiExecutiveDecisionPack> _dedupePacks(
    List<AiExecutiveDecisionPack> packs,
  ) {
    final seen = <String>{};
    final result = <AiExecutiveDecisionPack>[];
    for (final pack in packs) {
      final key = pack.summary.toLowerCase();
      if (seen.add(key)) result.add(pack);
    }
    return result;
  }

  int _riskRank(AiFinancialRiskLevel level) {
    switch (level) {
      case AiFinancialRiskLevel.high:
        return 3;
      case AiFinancialRiskLevel.medium:
        return 2;
      case AiFinancialRiskLevel.low:
        return 1;
    }
  }
}
