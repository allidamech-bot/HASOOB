import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_business_memory.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_customer_credit_intelligence.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_executive_cfo_autonomy.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_snapshot.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_import_export_cfo_advisor.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_insight_generator.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_risk_detector.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/financial_reasoning_engine.dart';

void main() {
  group('Executive CFO autonomy', () {
    test('generates executive briefing with evidence and confidence', () {
      final evidence = _overviewEvidence();
      final snapshot = AiFinancialSnapshot.fromEvidence(evidence);
      final risks = AiRiskDetector().detect(snapshot);
      final recommendations = AiInsightGenerator().generateRecommendations(
        snapshot: snapshot,
        risks: risks,
      );

      final briefing = AiExecutiveCfoAutonomy().generateBriefing(
        snapshot: snapshot,
        evidence: evidence,
        risks: risks,
        recommendations: recommendations,
      );

      expect(briefing.businessHealthSummary, contains('executive attention'));
      expect(briefing.cashStatus, contains('pending invoices'));
      expect(briefing.topRisks, isNotEmpty);
      expect(briefing.urgentDecisionsRequired, isNotEmpty);
      expect(briefing.recommendedExecutiveActions, isNotEmpty);
      expect(briefing.confidenceScore, greaterThanOrEqualTo(65));
      expect(briefing.evidenceReferences.join(' '), contains('getInvoices'));
    });

    test('generates complete decision pack with guarded next step', () {
      const alert = AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.fallingCashReserves,
        level: AiFinancialRiskLevel.high,
        summary: 'Cash reserve risk',
        explanation: 'Receivables are overdue before new spend.',
        evidence: ['pending invoices 4000'],
        confidence: AiEvidenceConfidence.high,
      );

      final packs = AiExecutiveCfoAutonomy().generateDecisionPacks(
        snapshot: _lossSnapshot(),
        alerts: [alert],
      );
      final pack = packs.single;

      expect(pack.summary, contains('Postpone non-critical expense'));
      expect(pack.reasoning, contains('Receivables are overdue'));
      expect(pack.evidence, contains('pending invoices 4000'));
      expect(pack.confidence, AiEvidenceConfidence.high);
      expect(pack.expectedFinancialImpact, contains('cash reserves'));
      expect(pack.riskLevel, AiFinancialRiskLevel.high);
      expect(pack.actionOptions, contains('Defer execution'));
      expect(pack.recommendedNextStep, contains('proposal/workflow approval'));
      expect(pack.requiresApproval, isTrue);
    });

    test('detects cash reserve risk alert', () {
      final alerts = AiExecutiveCfoAutonomy().monitorRisks(
        snapshot: _lossSnapshot(),
        evidence: _overviewEvidence(),
      );

      expect(
        alerts.map((alert) => alert.type),
        contains(AiExecutiveRiskType.fallingCashReserves),
      );
    });

    test('detects customer concentration and overdue risk', () {
      final credit =
          AiCustomerCreditIntelligence().analyze(_customerEvidence());

      final alerts = AiExecutiveCfoAutonomy().monitorRisks(
        snapshot: _lossSnapshot(),
        evidence: _overviewEvidence(),
        customerCredit: credit,
      );

      expect(
        alerts.map((alert) => alert.type),
        contains(AiExecutiveRiskType.customerConcentration),
      );
      expect(
        alerts.map((alert) => alert.type),
        contains(AiExecutiveRiskType.overdueCustomer),
      );
      expect(alerts.map((alert) => alert.summary).join(' '),
          contains('Slow Buyer'));
    });

    test('creates import/export risk recommendation', () {
      final shipment = AiImportExportCfoAdvisor().evaluateShipment(
        const AiShipmentDecisionInput(
          purchaseCostPerUnit: 45,
          freightCost: 500,
          customsCost: 200,
          storageCost: 100,
          sellingPricePerUnit: 50,
          expectedVolume: 100,
          evidence: [
            'supplier quote',
            'freight quote',
            'expected selling price',
          ],
        ),
      );

      final alerts = AiExecutiveCfoAutonomy().monitorRisks(
        snapshot: _lossSnapshot(),
        evidence: _overviewEvidence(),
        shipmentDecision: shipment,
      );
      final packs = AiExecutiveCfoAutonomy().generateDecisionPacks(
        snapshot: _lossSnapshot(),
        alerts: alerts,
      );

      expect(
        alerts.map((alert) => alert.type),
        contains(AiExecutiveRiskType.importExportShipment),
      );
      expect(
        packs.map((pack) => pack.summary).join(' '),
        contains('Renegotiate shipment terms'),
      );
    });

    test('uses long-term memory to support recommendation', () {
      final memory = AiCfoMemoryItem(
        id: 'mem-cash',
        category: AiCfoMemoryCategory.financial,
        summary: 'This repeats a prior cashflow warning.',
        source: 'AI Financial Snapshot',
        sourceType: 'financial_snapshot',
        timestamp: DateTime(2026, 1, 1),
        confidence: AiEvidenceConfidence.high,
        relatedEntity: 'cashflow',
        evidenceReferences: const ['pending invoices 4000'],
      );
      const alert = AiExecutiveRiskAlert(
        type: AiExecutiveRiskType.fallingCashReserves,
        level: AiFinancialRiskLevel.high,
        summary: 'Cash reserve risk',
        explanation: 'Receivables are overdue before new spend.',
        evidence: ['pending invoices 4000'],
        confidence: AiEvidenceConfidence.high,
      );

      final packs = AiExecutiveCfoAutonomy().generateDecisionPacks(
        snapshot: _lossSnapshot(),
        alerts: [alert],
        memories: [memory],
      );

      expect(packs.single.reasoning,
          contains('This repeats a prior cashflow warning'));
    });

    test('safety keeps recommendations advisory and non-executing', () {
      final briefing = AiExecutiveCfoAutonomy().generateBriefing(
        snapshot: _lossSnapshot(),
        evidence: _overviewEvidence(),
        risks: AiRiskDetector().detect(_lossSnapshot()),
      );

      for (final pack in briefing.recommendedExecutiveActions) {
        expect(pack.requiresApproval, isTrue);
        expect(
            pack.recommendedNextStep, contains('proposal/workflow approval'));
        expect(pack.recommendedNextStep, isNot(contains('create invoice')));
        expect(pack.recommendedNextStep, isNot(contains('record payment')));
        expect(
            pack.recommendedNextStep, isNot(contains('approve automatically')));
      }
    });

    test('financial overview response includes executive briefing context', () {
      final response = FinancialReasoningEngine().buildGroundedResponse(
        plan: _overviewPlan,
        evidence: _overviewEvidence(),
      );

      expect(response, contains('Executive Briefing:'));
      expect(response, contains('Decision Packs:'));
      expect(response, contains('Confidence score:'));
      expect(response, contains('proposal/workflow approval'));
    });
  });
}

AiFinancialSnapshot _lossSnapshot() {
  return const AiFinancialSnapshot(
    revenue: 1000,
    expenses: 1400,
    profit: -400,
    pendingInvoices: 4000,
    overdueInvoices: 3,
    inventoryHealth: 'needs_attention',
    lowStockProducts: 2,
    customerRisk: 'open_balances',
    confidence: AiEvidenceConfidence.high,
  );
}

AiEvidenceBundle _overviewEvidence() {
  return AiEvidenceBundle.fromToolResults(
    plan: _overviewPlan,
    tools: [
      const AiExecutedToolEvidence(
        toolName: 'getFinancialSummary',
        success: true,
        reason:
            'Understand income, expenses, profit, cash flow, and receivables.',
        data: {
          'totalIncome': 1000,
          'totalExpenses': 1400,
          'totalProfit': -400,
          'accountsReceivable': 4000,
        },
      ),
      AiExecutedToolEvidence(
        toolName: 'getInvoices',
        success: true,
        reason: 'Check pending invoice exposure.',
        data: {
          'outstanding': 4000,
          'records': [
            {
              'status': 'overdue',
              'remaining_amount': 4000,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 10))
                  .toIso8601String(),
            },
          ],
        },
      ),
      const AiExecutedToolEvidence(
        toolName: 'getProducts',
        success: true,
        reason: 'Check inventory exposure and stock risk.',
        data: {
          'records': [
            {'stock_qty': 1, 'low_stock_threshold': 5},
          ],
        },
      ),
      const AiExecutedToolEvidence(
        toolName: 'getCustomers',
        success: true,
        reason: 'Check customer balance and receivables risk.',
        data: {'totalOutstanding': 4000, 'records': []},
      ),
    ],
  );
}

AiEvidenceBundle _customerEvidence() {
  return AiEvidenceBundle.fromToolResults(
    plan: _customerPlan,
    tools: [
      const AiExecutedToolEvidence(
        toolName: 'getCustomers',
        success: true,
        reason: 'Review customer balances and receivables exposure.',
        data: {
          'totalOutstanding': 10000,
          'records': [
            {
              'id': 'c-slow',
              'name': 'Slow Buyer',
              'outstanding_balance': 8500,
            },
            {
              'id': 'c-other',
              'name': 'Other Buyer',
              'outstanding_balance': 1500,
            },
          ],
        },
      ),
      AiExecutedToolEvidence(
        toolName: 'getInvoices',
        success: true,
        reason:
            'Review invoice history, overdue frequency, and payment delays.',
        data: {
          'records': [
            {
              'customer_id': 'c-slow',
              'customer_name': 'Slow Buyer',
              'status': 'overdue',
              'total': 8500,
              'paid_amount': 0,
              'remaining_amount': 8500,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 50))
                  .toIso8601String(),
            },
          ],
        },
      ),
    ],
  );
}

const _overviewPlan = AiToolPlan(
  intent: AiAccountantIntent.financialOverview,
  requiresTools: true,
  steps: [
    AiToolStep(
      toolName: 'getFinancialSummary',
      reason:
          'Understand income, expenses, profit, cash flow, and receivables.',
      required: true,
    ),
    AiToolStep(
      toolName: 'getInvoices',
      reason: 'Check pending invoice exposure.',
      required: false,
    ),
    AiToolStep(
      toolName: 'getProducts',
      reason: 'Check inventory exposure and stock risk.',
      required: false,
    ),
    AiToolStep(
      toolName: 'getCustomers',
      reason: 'Check customer balance and receivables risk.',
      required: false,
    ),
  ],
  missingInputs: [],
  safetyLevel: AiToolSafetyLevel.readOnly,
);

const _customerPlan = AiToolPlan(
  intent: AiAccountantIntent.customerBalanceAnalysis,
  requiresTools: true,
  steps: [
    AiToolStep(
      toolName: 'getCustomers',
      reason: 'Review customer balances and receivables exposure.',
      required: true,
    ),
    AiToolStep(
      toolName: 'getInvoices',
      reason: 'Review invoice history, overdue frequency, and payment delays.',
      required: true,
    ),
  ],
  missingInputs: [],
  safetyLevel: AiToolSafetyLevel.readOnly,
);
