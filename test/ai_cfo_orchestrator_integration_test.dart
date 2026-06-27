import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/features/ai_accountant/data/tools/financial_tools.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_conversation_orchestrator.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';

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
    test('local English sale missing cost accepts cost follow-up', () async {
      final orchestrator = AiConversationOrchestrator();

      await orchestrator.generateResponse(
        userText: 'I sold 5 boxes for 40 each',
      );
      final response = await orchestrator.generateResponse(
        userText: 'cost was 28',
      );

      expect(response.text, contains('Previous operation updated'));
      expect(response.text, contains('* Quantity: 5'));
      expect(response.text, contains('* Unit selling price: 40'));
      expect(response.text, contains('* Unit cost: 28'));
      expect(response.text, contains('* Revenue: 200'));
      expect(response.text, contains('* Cost: 140'));
      expect(response.text, contains('* Profit: 60'));
      expect(response.text, contains('* Profit margin: 30%'));
      expect(response.text, contains('Ready as a reviewable draft'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test('local Arabic sale missing cost accepts cost follow-up', () async {
      final orchestrator = AiConversationOrchestrator();

      await orchestrator.generateResponse(
        userText: 'بعت 5 كراتين بسعر 40',
      );
      final response = await orchestrator.generateResponse(
        userText: 'تكلفتها 28',
      );

      expect(response.text, contains('تم تحديث العملية السابقة'));
      expect(response.text, contains('الكمية'));
      expect(response.text, contains('تكلفة الوحدة'));
      expect(response.text, contains('الإيراد'));
      expect(response.text, contains('التكلفة'));
      expect(response.text, contains('الربح'));
      expect(response.text, contains('هامش الربح'));
      expect(response.text, contains('جاهزة كمسودة'));
      expect(response.shouldPrepareProposal, isFalse);
    });

    test(
        'cost follow-up state does not intercept business health without pending sale',
        () async {
      final orchestrator = AiConversationOrchestrator(
        financialTools: _IntegrationFinancialTools(),
      );

      final response = await orchestrator.generateResponse(
        userText: 'What is my current business health?',
      );

      expect(response.text, isNot(contains('Previous operation updated')));
      expect(response.metadata, isNotNull);
      expect(
        response.metadata!.confidenceLevel,
        isNot(AiEvidenceConfidence.low),
      );
      expect(response.metadata!.executedTools, isNotEmpty);
      expect(response.shouldPrepareProposal, isFalse);
    });
  });
}

class _IntegrationFinancialTools extends FinancialTools {
  @override
  Future<FinancialToolResult> getFinancialSummary({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    return FinancialToolResult.success({
      'totalIncome': 12000,
      'totalExpenses': 9000,
      'totalProfit': 3000,
      'netCashFlow': 3000,
      'accountsReceivable': 8500,
      'profitMargin': 25,
    });
  }

  @override
  Future<FinancialToolResult> getInvoices({
    required String businessId,
    String? status,
    int limit = 100,
  }) async {
    return FinancialToolResult.success({
      'totalAmount': 10000,
      'totalPaid': 1500,
      'outstanding': 8500,
      'count': 2,
      'records': const [],
    });
  }

  @override
  Future<FinancialToolResult> getCustomers({
    required String businessId,
    String? searchQuery,
    int limit = 100,
  }) async {
    return FinancialToolResult.success({
      'totalOutstanding': 8500,
      'count': 1,
      'records': const [],
    });
  }

  @override
  Future<FinancialToolResult> getProducts({
    required String businessId,
    String? searchQuery,
    bool lowStockOnly = false,
    int limit = 100,
  }) async {
    return FinancialToolResult.success({
      'totalValue': 1200,
      'count': 1,
      'records': const [],
    });
  }
}
