import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('AiToolPlanner', () {
    late AiToolPlanner planner;

    setUp(() {
      planner = AiToolPlanner();
    });

    test('classifies financial overview as read-only tool-backed work', () {
      final plan = planner.plan(
        userText: 'How is the business doing?',
        businessId: 'business-1',
      );

      expect(plan.intent, AiAccountantIntent.financialOverview);
      expect(plan.requiresTools, isTrue);
      expect(plan.safetyLevel, AiToolSafetyLevel.readOnly);
      expect(
        plan.steps.map((step) => step.toolName),
        contains('getFinancialSummary'),
      );
    });

    test('execution intent requires guard and no read tools', () {
      final plan = planner.plan(
        userText: 'execute',
        businessId: 'business-1',
      );

      expect(plan.intent, AiAccountantIntent.executionIntent);
      expect(plan.requiresTools, isFalse);
      expect(plan.steps, isEmpty);
      expect(plan.safetyLevel, AiToolSafetyLevel.executionGuard);
    });

    test('general advice does not require tools', () {
      final plan = planner.plan(
        userText: 'I need advice about growing my business',
        businessId: 'business-1',
      );

      expect(plan.intent, AiAccountantIntent.generalAdvice);
      expect(plan.requiresTools, isFalse);
      expect(plan.safetyLevel, AiToolSafetyLevel.advisoryOnly);
    });

    test('classifies invoice review as read-only analysis', () {
      final plan = planner.plan(
        userText: 'review pending invoices',
        businessId: 'business-1',
      );

      expect(plan.intent, AiAccountantIntent.invoiceAnalysis);
      expect(plan.requiresTools, isTrue);
      expect(plan.safetyLevel, AiToolSafetyLevel.readOnly);
      expect(plan.steps.single.toolName, 'getInvoices');
    });
  });
}
