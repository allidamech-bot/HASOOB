import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_decision_questionnaire.dart';

void main() {
  group('AiDecisionQuestionnaire', () {
    test('progresses one question at a time', () {
      final questionnaire = AiDecisionQuestionnaire();
      var state = questionnaire.start(
        decisionType: 'inventoryPurchase',
        requiredInputs: const [
          AiDecisionInputField.quantity,
          AiDecisionInputField.unitCost,
          AiDecisionInputField.expectedSellingPrice,
        ],
      );

      expect(state.nextMissingInput, AiDecisionInputField.quantity);
      expect(
        questionnaire.questionFor(state.nextMissingInput!),
        'What quantity are you considering?',
      );

      state = questionnaire.continueWith('500 cartons')!;
      expect(state.collectedInputs[AiDecisionInputField.quantity], 500);
      expect(state.nextMissingInput, AiDecisionInputField.unitCost);

      state = questionnaire.continueWith('12 SAR')!;
      expect(state.collectedInputs[AiDecisionInputField.unitCost], 12);
      expect(state.nextMissingInput, AiDecisionInputField.expectedSellingPrice);
    });

    test('does not accept invalid numeric input', () {
      final questionnaire = AiDecisionQuestionnaire();
      final state = questionnaire.start(
        decisionType: 'inventoryPurchase',
        requiredInputs: const [AiDecisionInputField.quantity],
      );

      final next = questionnaire.continueWith('many cartons')!;
      expect(next.collectedInputs, isEmpty);
      expect(next.nextMissingInput, state.nextMissingInput);
    });
  });
}
