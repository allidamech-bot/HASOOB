import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_response_metadata.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('AiResponseMetadata', () {
    test('creates high confidence metadata from direct tool evidence', () {
      const plan = AiToolPlan(
        intent: AiAccountantIntent.financialOverview,
        requiresTools: true,
        steps: [
          AiToolStep(
            toolName: 'getFinancialSummary',
            reason: 'Review financial summary.',
            required: true,
          ),
          AiToolStep(
            toolName: 'getInvoices',
            reason: 'Review invoices.',
            required: false,
          ),
        ],
        missingInputs: [],
        safetyLevel: AiToolSafetyLevel.readOnly,
      );
      final evidence = AiEvidenceBundle.fromToolResults(
        plan: plan,
        tools: const [
          AiExecutedToolEvidence(
            toolName: 'getFinancialSummary',
            success: true,
            reason: 'Review financial summary.',
            data: {'totalIncome': 1000},
          ),
          AiExecutedToolEvidence(
            toolName: 'getInvoices',
            success: true,
            reason: 'Review invoices.',
            data: {
              'records': [
                {'id': 'inv-1'},
                {'id': 'inv-2'},
              ],
              'count': 2,
            },
          ),
        ],
      );

      final metadata = AiResponseMetadata.fromEvidence(evidence);

      expect(metadata.confidenceLabel, 'HIGH');
      expect(metadata.evidenceCount, 2);
      expect(metadata.executedTools, ['getFinancialSummary', 'getInvoices']);
    });

    test('creates low confidence metadata for advisory-only evidence', () {
      const plan = AiToolPlan(
        intent: AiAccountantIntent.generalAdvice,
        requiresTools: false,
        steps: [],
        missingInputs: ['confirmed invoice data'],
        safetyLevel: AiToolSafetyLevel.advisoryOnly,
      );

      final metadata = AiResponseMetadata.fromEvidence(
        AiEvidenceBundle.empty(plan: plan),
      );

      expect(metadata.confidenceLabel, 'LOW');
      expect(metadata.evidenceCount, 0);
      expect(metadata.executedTools, isEmpty);
      expect(metadata.missingEvidence, contains('confirmed invoice data'));
    });

    test('maps tool names to user-facing labels', () {
      final metadata = AiResponseMetadata(
        confidenceLevel: AiEvidenceConfidence.medium,
        executedTools: ['getFinancialSummary', 'getProducts', 'getInvoices'],
        missingEvidence: const [],
        evidenceCount: 3,
        generatedAt: DateTime(2026),
      );

      expect(metadata.executedToolLabels, [
        'Financial Summary',
        'Products',
        'Invoices',
      ]);
    });

    test('preserves missing evidence for UI visibility', () {
      final metadata = AiResponseMetadata.low(
        missingEvidence: const ['customer balances', 'invoice data'],
      );

      expect(metadata.missingEvidence, [
        'customer balances',
        'invoice data',
      ]);
    });
  });
}
