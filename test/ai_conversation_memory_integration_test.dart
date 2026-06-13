import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_conversation_orchestrator.dart';

void main() {
  group('AiConversationOrchestrator business memory', () {
    test('uses remembered product in workflow follow-up', () async {
      final orchestrator = AiConversationOrchestrator();

      await orchestrator.generateResponse(userText: 'prepare purchase');
      await orchestrator.generateResponse(userText: 'Ülker Hobby');
      await orchestrator.generateResponse(userText: '100');
      await orchestrator.generateResponse(userText: '12');

      final response = await orchestrator.generateResponse(
        userText: 'prepare purchase',
      );

      expect(orchestrator.businessMemory.recentProducts.first, 'Ülker Hobby');
      expect(response.text, contains('Ülker Hobby'));
    });
  });
}
