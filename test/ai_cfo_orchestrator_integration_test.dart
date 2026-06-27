import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_conversation_orchestrator.dart';

void main() {
  group('AiConversationOrchestrator CFO decision integration', () {
    setUpAll(() {
      BusinessContext.initialize(
        businessId: 'qa-business',
        userId: 'qa-user',
        role: 'owner',
      );
    });

    test('decision request returns CFO view and no proposal side effect',
        () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'Should I buy 500 cartons?',
      );

      expect(response.text, contains('CFO View'));
      expect(response.text, contains('Recommendation:'));
      expect(response.text, contains('Next Question:'));
      expect(response.text, contains('purchase cost'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('questionnaire progresses through decision inputs', () async {
      final orchestrator = AiConversationOrchestrator();

      await orchestrator.generateResponse(
          userText: 'Should I buy 500 cartons?');
      final costResponse =
          await orchestrator.generateResponse(userText: '12 SAR');
      final priceResponse =
          await orchestrator.generateResponse(userText: '18 SAR');

      expect(costResponse.text, contains('expected selling price'));
      expect(priceResponse.text, contains('demand'));
      expect(priceResponse.shouldPrepareProposal, isFalse);
    });

    test('complete decision can disagree with risky action', () async {
      final orchestrator = AiConversationOrchestrator();

      await orchestrator.generateResponse(
          userText: 'Should I buy 500 cartons?');
      await orchestrator.generateResponse(userText: '12 SAR');
      await orchestrator.generateResponse(userText: '18 SAR');
      final response = await orchestrator.generateResponse(
        userText: 'I do not have confirmed demand yet',
      );

      expect(response.text, contains('CFO View'));
      expect(response.text, contains('I do not recommend'));
      expect(response.text, contains('Scenarios:'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local sale message calculates revenue cost and margin', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'sold 10 units at 25 cost 15',
      );

      expect(response.text, contains('Sale analyzed:'));
      expect(response.text, contains('Revenue: 250'));
      expect(response.text, contains('Cost: 150'));
      expect(response.text, contains('Profit: 100'));
      expect(response.text, contains('Profit margin: 40%'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local sale message asks for missing unit cost', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'I sold 5 boxes for 40 each',
      );

      expect(response.text, contains('total revenue 200'));
      expect(response.text, contains('unit cost is missing'));
      expect(response.memory.missingData, contains('unit cost'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local expense message prepares review-only response', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'paid shipping expense 300',
      );

      expect(response.text, contains('Shipping expense understood for 300'));
      expect(response.text, contains('will not be posted before approval'));
      expect(response.shouldPrepareProposal, isFalse);
    });
  });
}
