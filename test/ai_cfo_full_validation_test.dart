import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/features/ai_accountant/data/tools/financial_tools.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_conversation_orchestrator.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';

void main() {
  group('Full AI CFO validation', () {
    setUpAll(() {
      BusinessContext.initialize(
        businessId: 'h1-business',
        userId: 'h1-user',
        role: 'owner',
      );
    });

    test('end-to-end CFO questions stay evidence-backed and guarded', () async {
      final orchestrator = AiConversationOrchestrator(
        financialTools: _ValidationFinancialTools(),
      );

      final questions = [
        'What is my current business health?',
        'What are my top risks?',
        'Which customers are risky?',
        'What happens if customer payments are delayed?',
        'What should I do this week as CFO?',
        'What decisions need my approval?',
      ];

      for (final question in questions) {
        final response = await orchestrator.generateResponse(
          userText: question,
        );

        expect(response.shouldPrepareProposal, isFalse);
        expect(response.metadata, isNotNull);
        expect(
            response.metadata!.confidenceLevel, isNot(AiEvidenceConfidence.low),
            reason: question);
        expect(response.metadata!.executedTools, isNotEmpty);
        expect(response.text, isNot(contains('approve automatically')));
        expect(response.text, isNot(contains('created invoice')));
        expect(response.text, isNot(contains('recorded payment')));
      }
    });

    test('import question remains advisory until required inputs are supplied',
        () async {
      final orchestrator = AiConversationOrchestrator(
        financialTools: _ValidationFinancialTools(),
      );

      final response = await orchestrator.generateResponse(
        userText: 'Should I import this shipment?',
      );

      expect(response.shouldPrepareProposal, isFalse);
      expect(response.metadata, isNotNull);
      expect(response.metadata!.confidenceLevel, AiEvidenceConfidence.low);
      expect(response.text, contains('Missing Information'));
      expect(response.text, contains('Next Question'));
      expect(response.text, isNot(contains('approved')));
    });

    test('executable requests route through proposal guard only', () async {
      final orchestrator = AiConversationOrchestrator(
        financialTools: _ValidationFinancialTools(),
      );

      final response = await orchestrator.generateResponse(
        userText: 'approve and create the invoice now',
      );

      expect(response.shouldPrepareProposal, isFalse);
      expect(response.text, contains('clear proposal'));
      expect(response.text, isNot(contains('created invoice')));
      expect(response.text, isNot(contains('recorded payment')));
    });

    test('memory appears only after relevant evidence-backed prior analysis',
        () async {
      final orchestrator = AiConversationOrchestrator(
        financialTools: _ValidationFinancialTools(),
      );

      final first = await orchestrator.generateResponse(
        userText: 'Which customers are risky?',
      );
      final second = await orchestrator.generateResponse(
        userText: 'Which customers are risky?',
      );
      final unrelated = await orchestrator.generateResponse(
        userText: 'Analyze inventory',
      );

      expect(first.text, isNot(contains('Relevant Memory:')));
      expect(second.text, contains('Relevant Memory:'));
      expect(second.text, contains('source: Customer Credit Intelligence'));
      expect(second.text, contains('confidence: HIGH'));
      expect(unrelated.text, isNot(contains('Relevant Memory:')));
    });
  });
}

class _ValidationFinancialTools extends FinancialTools {
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
      'records': [
        {
          'id': 'inv-slow-1',
          'customer_id': 'c-slow',
          'customer_name': 'Slow Buyer',
          'status': 'overdue',
          'total': 5000,
          'paid_amount': 0,
          'remaining_amount': 5000,
          'due_date': DateTime.now()
              .subtract(const Duration(days: 45))
              .toIso8601String(),
        },
        {
          'id': 'inv-slow-2',
          'customer_id': 'c-slow',
          'customer_name': 'Slow Buyer',
          'status': 'issued',
          'total': 3500,
          'paid_amount': 0,
          'remaining_amount': 3500,
          'due_date': DateTime.now()
              .subtract(const Duration(days: 20))
              .toIso8601String(),
        },
      ],
    });
  }

  @override
  Future<FinancialToolResult> getCustomers({
    required String businessId,
    String? searchQuery,
    int limit = 100,
  }) async {
    return FinancialToolResult.success({
      'totalOutstanding': 10000,
      'count': 2,
      'records': [
        {
          'id': 'c-slow',
          'name': 'Slow Buyer',
          'outstanding_balance': 8500,
        },
        {
          'id': 'c-steady',
          'name': 'Steady Buyer',
          'outstanding_balance': 1500,
        },
      ],
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
      'records': [
        {
          'id': 'p-low',
          'name': 'Fast Product',
          'stock_qty': 1,
          'low_stock_threshold': 5,
          'purchase_price': 20,
        },
      ],
    });
  }
}
