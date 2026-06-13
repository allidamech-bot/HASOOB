import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_data_collection_state.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_workflow_manager.dart';

void main() {
  group('AiWorkflowManager', () {
    late AiWorkflowManager manager;

    setUp(() {
      manager = AiWorkflowManager();
    });

    test('purchase workflow asks one question at a time and completes', () {
      var result = manager.handleMessage('اشتريت شوكولاتة');
      expect(result, isNotNull);
      expect(result!.session!.workflowType, AiWorkflowType.purchase);
      expect(result.session!.waitingField, AiWorkflowField.product);
      expect(result.responseText, contains('product'));

      result = manager.handleMessage('Ulker Hobby');
      expect(result!.session!.collectedData[AiWorkflowField.product],
          'Ulker Hobby');
      expect(result.session!.waitingField, AiWorkflowField.quantity);

      result = manager.handleMessage('100');
      expect(result!.session!.collectedData[AiWorkflowField.quantity], 100);
      expect(result.session!.waitingField, AiWorkflowField.cost);

      result = manager.handleMessage('12');
      expect(result!.isComplete, isTrue);
      expect(result.proposalDraftText, contains('purchase proposal'));
      expect(manager.activeSession, isNull);
    });

    test('sale workflow resumes and completes with customer and price', () {
      var result = manager.handleMessage('بعت 50 كرتون');
      expect(result!.session!.workflowType, AiWorkflowType.sale);
      expect(result.session!.waitingField, AiWorkflowField.product);

      result = manager.handleMessage('Chocolate');
      expect(result!.session!.waitingField, AiWorkflowField.quantity);

      result = manager.handleMessage('50');
      expect(result!.session!.waitingField, AiWorkflowField.customer);

      result = manager.handleMessage('Ahmed Store');
      expect(result!.session!.waitingField, AiWorkflowField.sellingPrice);

      result = manager.handleMessage('18');
      expect(result!.isComplete, isTrue);
      expect(result.proposalDraftText, contains('sale proposal'));
    });

    test('pricing workflow completes as pricing simulation draft', () {
      var result = manager.handleMessage('سعر المنتج مناسب؟');
      expect(result!.session!.workflowType, AiWorkflowType.pricing);

      result = manager.handleMessage('Chocolate');
      expect(result!.session!.waitingField, AiWorkflowField.cost);

      result = manager.handleMessage('10');
      expect(result!.session!.waitingField, AiWorkflowField.sellingPrice);

      result = manager.handleMessage('15');
      expect(result!.isComplete, isTrue);
      expect(result.proposalDraftText, contains('pricing simulation'));
    });

    test('invalid numeric input is rejected politely', () {
      manager.handleMessage('prepare purchase');
      manager.handleMessage('Chocolate');

      final result = manager.handleMessage('0');

      expect(result!.isComplete, isFalse);
      expect(result.session!.waitingField, AiWorkflowField.quantity);
      expect(result.responseText, contains('greater than zero'));
    });

    test('workflow cancellation clears active session', () {
      manager.handleMessage('prepare purchase');

      final result = manager.handleMessage('Cancel');

      expect(result!.isCancelled, isTrue);
      expect(manager.activeSession, isNull);
    });

    test('unknown conversation does not start workflow', () {
      final result = manager.handleMessage('hello');

      expect(result, isNull);
      expect(manager.activeSession, isNull);
    });
  });
}
