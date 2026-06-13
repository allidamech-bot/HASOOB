import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_customer_credit_intelligence.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/financial_reasoning_engine.dart';

void main() {
  group('AiCustomerCreditIntelligence', () {
    test('scores customers from balances, invoice history, and delays', () {
      final evidence = _customerCreditEvidence();

      final report = AiCustomerCreditIntelligence().analyze(evidence);
      final top = report.riskiestCustomer!;

      expect(report.scoringModel, contains('Risk score 0-100'));
      expect(report.evidenceSources, hasLength(2));
      expect(top.customerName, 'Slow Buyer');
      expect(top.riskLevel, AiCustomerCreditRiskLevel.critical);
      expect(top.overdueCount, 2);
      expect(top.invoiceCount, 2);
      expect(top.outstandingBalance, 8500);
      expect(top.concentrationRisk, closeTo(0.85, 0.01));
      expect(top.evidence.join(' '), contains('Average payment delay'));
      expect(top.recommendedAction, contains('Stop extending credit'));
    });

    test('reasoning response exposes score, evidence, confidence, and action',
        () {
      final response = FinancialReasoningEngine().buildGroundedResponse(
        plan: _customerCreditPlan,
        evidence: _customerCreditEvidence(),
      );

      expect(response, contains('Customer Credit Intelligence'));
      expect(response, contains('Scoring Model:'));
      expect(response, contains('Highest Risk Customer: Slow Buyer'));
      expect(response, contains('Evidence:'));
      expect(response, contains('Confidence: HIGH'));
      expect(response, contains('Recommended Action:'));
    });

    test('planner detects customer credit risk questions', () {
      final plan = AiToolPlanner().plan(
        userText: 'Which customers are becoming risky?',
        businessId: 'b1',
      );

      expect(plan.intent, AiAccountantIntent.customerBalanceAnalysis);
      expect(plan.steps.map((step) => step.toolName), [
        'getCustomers',
        'getInvoices',
      ]);
    });
  });
}

AiEvidenceBundle _customerCreditEvidence() {
  return AiEvidenceBundle.fromToolResults(
    plan: _customerCreditPlan,
    tools: [
      const AiExecutedToolEvidence(
        toolName: 'getCustomers',
        success: true,
        reason: 'Review customer balances and receivables exposure.',
        data: {
          'totalOutstanding': 10000,
          'count': 2,
          'records': [
            {
              'id': 'c-slow',
              'name': 'Slow Buyer',
              'outstanding_balance': 8500,
            },
            {
              'id': 'c-steady',
              'name': 'Steady Buyer',
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
          'count': 3,
          'records': [
            {
              'id': 'i-1',
              'customer_id': 'c-slow',
              'customer_name': 'Slow Buyer',
              'status': 'issued',
              'total': 5000,
              'paid_amount': 0,
              'remaining_amount': 5000,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 70))
                  .toIso8601String(),
            },
            {
              'id': 'i-2',
              'customer_id': 'c-slow',
              'customer_name': 'Slow Buyer',
              'status': 'overdue',
              'total': 3500,
              'paid_amount': 0,
              'remaining_amount': 3500,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 50))
                  .toIso8601String(),
            },
            {
              'id': 'i-3',
              'customer_id': 'c-steady',
              'customer_name': 'Steady Buyer',
              'status': 'paid',
              'total': 2000,
              'paid_amount': 2000,
              'remaining_amount': 0,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 20))
                  .toIso8601String(),
            },
          ],
        },
      ),
    ],
  );
}

const _customerCreditPlan = AiToolPlan(
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
