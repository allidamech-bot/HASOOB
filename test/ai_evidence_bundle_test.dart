import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('AiEvidenceBundle', () {
    test('empty evidence has low confidence', () {
      const plan = AiToolPlan(
        intent: AiAccountantIntent.generalAdvice,
        requiresTools: false,
        steps: [],
        missingInputs: ['cost'],
        safetyLevel: AiToolSafetyLevel.advisoryOnly,
      );

      final bundle = AiEvidenceBundle.empty(plan: plan);

      expect(bundle.confidenceLevel, AiEvidenceConfidence.low);
      expect(bundle.missingEvidence, contains('cost'));
      expect(bundle.hasToolData, isFalse);
    });

    test('direct successful overview evidence has high confidence', () {
      const plan = AiToolPlan(
        intent: AiAccountantIntent.financialOverview,
        requiresTools: true,
        steps: [
          AiToolStep(
            toolName: 'getFinancialSummary',
            reason: 'Review summary.',
            required: true,
          ),
        ],
        missingInputs: [],
        safetyLevel: AiToolSafetyLevel.readOnly,
      );

      final bundle = AiEvidenceBundle.fromToolResults(
        plan: plan,
        tools: const [
          AiExecutedToolEvidence(
            toolName: 'getFinancialSummary',
            success: true,
            reason: 'Review summary.',
            data: {
              'totalIncome': 100,
              'totalExpenses': 40,
              'totalProfit': 60,
            },
          ),
        ],
      );

      expect(bundle.confidenceLevel, AiEvidenceConfidence.high);
      expect(bundle.hasToolData, isTrue);
      expect(bundle.summaries, contains('getFinancialSummary'));
    });
  });
}
