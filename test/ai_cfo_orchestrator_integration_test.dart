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

    test('local English sale message returns command card', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'sold 10 units at 25 cost 15',
      );

      expect(response.text, contains('Command interpreted as a sale'));
      expect(response.text, contains('Operation summary'));
      expect(response.text, contains('Revenue'));
      expect(response.text, contains('Profit margin'));
      expect(response.text, contains('Ready as a reviewable draft'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local English sale message shows missing unit cost', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'I sold 5 boxes for 40 each',
      );

      expect(response.text, contains('Operation summary'));
      expect(response.text, contains('Revenue'));
      expect(response.text, contains('Missing data'));
      expect(response.text, contains('Unit cost'));
      expect(response.memory.missingData, contains('unit cost'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local English expense message returns command card', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'paid shipping expense 300',
      );

      expect(response.text, contains('Command interpreted as an expense'));
      expect(response.text, contains('Expense summary'));
      expect(response.text, contains('Category'));
      expect(response.text, contains('Amount'));
      expect(response.text, contains('Reviewable draft'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local Arabic sale message returns command card', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'بعت 10 قطع بسعر 25 وتكلفتها 15',
      );

      expect(response.text, contains('ملخص العملية'));
      expect(response.text, contains('الإيراد'));
      expect(response.text, contains('الربح'));
      expect(response.text, contains('هامش الربح'));
      expect(response.text, contains('جاهزة كمسودة'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local Arabic sale message shows missing unit cost', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'بعت 5 كراتين بسعر 40',
      );

      expect(response.text, contains('ملخص العملية'));
      expect(response.text, contains('البيانات الناقصة'));
      expect(response.text, contains('تكلفة الوحدة'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local Arabic expense message returns command card', () async {
      final orchestrator = AiConversationOrchestrator();

      final response = await orchestrator.generateResponse(
        userText: 'دفعت مصروف شحن 300',
      );

      expect(response.text, contains('ملخص المصروف'));
      expect(response.text, contains('التصنيف'));
      expect(response.text, contains('المبلغ'));
      expect(response.text, contains('مسودة بانتظار المراجعة'));
      expect(response.shouldPrepareProposal, isFalse);
    });
  });
}
