import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_snapshot.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('AiFinancialSnapshot', () {
    test('creates snapshot from available evidence', () {
      final evidence = AiEvidenceBundle.fromToolResults(
        plan: _overviewPlan,
        tools: [
          const AiExecutedToolEvidence(
            toolName: 'getFinancialSummary',
            success: true,
            reason: 'summary',
            data: {
              'totalIncome': 1000,
              'totalExpenses': 400,
              'totalProfit': 600,
              'accountsReceivable': 250,
            },
          ),
          const AiExecutedToolEvidence(
            toolName: 'getInvoices',
            success: true,
            reason: 'invoices',
            data: {
              'outstanding': 250,
              'records': [
                {
                  'status': 'overdue',
                  'remaining_amount': 100,
                },
              ],
            },
          ),
          const AiExecutedToolEvidence(
            toolName: 'getProducts',
            success: true,
            reason: 'products',
            data: {
              'records': [
                {
                  'stock_qty': 2,
                  'low_stock_threshold': 5,
                },
              ],
            },
          ),
          const AiExecutedToolEvidence(
            toolName: 'getCustomers',
            success: true,
            reason: 'customers',
            data: {'totalOutstanding': 250, 'records': []},
          ),
        ],
      );

      final snapshot = AiFinancialSnapshot.fromEvidence(evidence);

      expect(snapshot.revenue, 1000);
      expect(snapshot.expenses, 400);
      expect(snapshot.profit, 600);
      expect(snapshot.pendingInvoices, 250);
      expect(snapshot.overdueInvoices, 1);
      expect(snapshot.lowStockProducts, 1);
      expect(snapshot.inventoryHealth, 'needs_attention');
      expect(snapshot.customerRisk, 'open_balances');
      expect(snapshot.confidence, AiEvidenceConfidence.high);
    });

    test('marks missing evidence and low confidence', () {
      final snapshot = AiFinancialSnapshot.fromEvidence(
        AiEvidenceBundle.empty(plan: _overviewPlan),
      );

      expect(snapshot.confidence, AiEvidenceConfidence.low);
      expect(snapshot.hasEvidence, isFalse);
      expect(snapshot.missingData, contains('invoices'));
      expect(snapshot.missingData, contains('customers'));
    });
  });
}

const _overviewPlan = AiToolPlan(
  intent: AiAccountantIntent.financialOverview,
  requiresTools: true,
  steps: [
    AiToolStep(
      toolName: 'getFinancialSummary',
      reason: 'summary',
      required: true,
    ),
    AiToolStep(
      toolName: 'getInvoices',
      reason: 'invoices',
      required: false,
    ),
    AiToolStep(
      toolName: 'getProducts',
      reason: 'products',
      required: false,
    ),
    AiToolStep(
      toolName: 'getCustomers',
      reason: 'customers',
      required: false,
    ),
  ],
  missingInputs: [],
  safetyLevel: AiToolSafetyLevel.readOnly,
);
