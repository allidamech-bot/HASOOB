import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_policy.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_decision_questionnaire.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_decision_engine.dart';

void main() {
  group('AiCfoPolicy', () {
    test('rejects large inventory without demand evidence', () {
      final policy = AiCfoPolicy();
      final decision = policy.evaluate(
        decisionType: AiFinancialDecisionType.inventoryPurchase,
        inputs: const {
          AiDecisionInputField.quantity: 500,
          AiDecisionInputField.unitCost: 12,
          AiDecisionInputField.expectedSellingPrice: 18,
        },
      );

      expect(decision.blocksRecommendation, isTrue);
      expect(decision.rationale, contains('do not recommend'));
      expect(decision.rationale, contains('demand evidence'));
    });

    test('rejects discount below cost', () {
      final policy = AiCfoPolicy();
      final decision = policy.evaluate(
        decisionType: AiFinancialDecisionType.pricingChange,
        inputs: const {
          AiDecisionInputField.unitCost: 12,
          AiDecisionInputField.proposedPrice: 10,
        },
      );

      expect(decision.blocksRecommendation, isTrue);
      expect(decision.rationale, contains('below cost'));
    });
  });
}
