import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_decision_questionnaire.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_decision_engine.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('AiFinancialDecisionEngine', () {
    late AiFinancialDecisionEngine engine;
    late AiDecisionQuestionnaire questionnaire;

    setUp(() {
      engine = AiFinancialDecisionEngine();
      questionnaire = AiDecisionQuestionnaire();
    });

    test('detects inventory purchase decision', () {
      expect(
        engine.detectDecisionType('Should I buy 500 cartons?'),
        AiFinancialDecisionType.inventoryPurchase,
      );
      expect(engine.isDecisionRequest('Should I buy 500 cartons?'), isTrue);
    });

    test('does not treat broad CFO action question as transaction decision',
        () {
      expect(
        engine.isDecisionRequest('What should I do this week as CFO?'),
        isFalse,
      );
    });

    test('missing evidence asks one next question', () {
      final state = questionnaire.start(
        decisionType: AiFinancialDecisionType.inventoryPurchase.name,
        requiredInputs: engine.requiredInputsFor(
          AiFinancialDecisionType.inventoryPurchase,
        ),
        seedInputs: const {AiDecisionInputField.quantity: 500},
      );

      const plan = AiToolPlan(
        intent: AiAccountantIntent.unknown,
        requiresTools: false,
        steps: [],
        missingInputs: [],
        safetyLevel: AiToolSafetyLevel.advisoryOnly,
      );
      final result = engine.evaluate(
        decisionType: AiFinancialDecisionType.inventoryPurchase,
        inputs: state.collectedInputs,
        evidence: AiEvidenceBundle.empty(plan: plan),
        questionnaire: questionnaire,
      );

      expect(result.recommendation, 'Do not decide yet.');
      expect(
          result.nextQuestion, 'What is the purchase cost per unit or carton?');
      expect(result.missingInputs, contains('unit cost'));
      expect(result.missingInputs, contains('expected selling price'));
    });

    test('creates scenario comparison without fabricating missing numbers', () {
      final scenarios = engine.compareScenarios(
        decisionType: AiFinancialDecisionType.inventoryPurchase,
        inputs: const {
          AiDecisionInputField.quantity: 300,
          AiDecisionInputField.unitCost: 10,
          AiDecisionInputField.expectedSellingPrice: 15,
        },
      );

      expect(scenarios, isNotEmpty);
      expect(scenarios.first.estimatedRevenue, isNotNull);
      expect(scenarios.first.estimatedCost, isNotNull);

      final incomplete = engine.compareScenarios(
        decisionType: AiFinancialDecisionType.inventoryPurchase,
        inputs: const {AiDecisionInputField.quantity: 300},
      );
      expect(incomplete, isEmpty);
    });
  });
}
