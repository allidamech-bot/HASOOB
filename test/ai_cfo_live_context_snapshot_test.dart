import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/tools/financial_tools.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_context_snapshot.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_context_snapshot_builder.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_intent.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_response.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_router.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_evidence.dart';

void main() {
  const builder = AiCfoContextSnapshotBuilder();
  const router = AiCfoConversationRouter();

  group('AiCfoContextSnapshotBuilder', () {
    test('empty inputs produce empty snapshot with data completeness notes',
        () {
      final snapshot = builder.buildFromToolResults();

      expect(snapshot.evidenceFor(AiCfoContextArea.businessHealth), isEmpty);
      expect(snapshot.dataCompletenessNotes, isNotEmpty);
    });

    test('inventory source produces sourced inventory evidence', () {
      final snapshot = builder.buildFromToolResults(
        products: FinancialToolResult.success({
          'records': [
            {'id': 'p-1', 'name': 'Widget', 'stock_qty': 3},
          ],
          'totalValue': 120.0,
          'count': 1,
        }),
      );

      expect(snapshot.inventorySummary, isNotEmpty);
      expect(
        snapshot.inventorySummary.every(
          (item) => item.source.trim().isNotEmpty,
        ),
        isTrue,
      );
      expect(
        snapshot.inventorySummary.map((item) => item.source),
        everyElement('FinancialTools.getProducts'),
      );
    });

    test('sales income source produces sourced sales evidence', () {
      final snapshot = builder.buildFromToolResults(
        income: FinancialToolResult.success({
          'records': [
            {'id': 's-1', 'total_sale': 80.0, 'total_profit': 20.0},
          ],
          'total': 80.0,
          'profit': 20.0,
          'count': 1,
        }),
      );

      expect(snapshot.salesSummary, isNotEmpty);
      expect(
        snapshot.salesSummary.every((item) => item.source.trim().isNotEmpty),
        isTrue,
      );
      expect(
        snapshot.salesSummary.map((item) => item.source),
        everyElement('FinancialTools.getIncome'),
      );
    });

    test('partial data produces data completeness notes', () {
      final snapshot = builder.buildFromToolResults(
        products: FinancialToolResult.success({
          'records': const [],
          'totalValue': 0.0,
          'count': 0,
        }),
      );

      expect(snapshot.dataCompletenessNotes, isNotEmpty);
      expect(
        snapshot.dataCompletenessNotes.join(' '),
        contains('Product tool returned no product records'),
      );
    });

    test('evidence confidence is not high when data is incomplete', () {
      final snapshot = builder.buildFromToolResults(
        products: FinancialToolResult.success({
          'records': const [],
          'totalValue': 0.0,
          'count': 0,
        }),
      );

      expect(snapshot.inventorySummary, isNotEmpty);
      expect(
        snapshot.inventorySummary.every(
          (item) => item.confidence != AiCfoEvidenceConfidence.high,
        ),
        isTrue,
      );
    });

    test('snapshot evidence makes business health response an answer', () {
      final snapshot = builder.buildFromToolResults(
        income: FinancialToolResult.success({
          'records': [
            {'id': 's-1', 'total_sale': 80.0, 'total_profit': 20.0},
          ],
          'total': 80.0,
          'profit': 20.0,
          'count': 1,
        }),
        products: FinancialToolResult.success({
          'records': [
            {'id': 'p-1', 'name': 'Widget', 'stock_qty': 3},
          ],
          'totalValue': 120.0,
          'count': 1,
        }),
      );

      final response = router.responseForIntent(
        AiCfoConversationIntent.businessHealth,
        context: snapshot,
      );

      expect(response.type, AiCfoResponseType.answer);
      expect(response.hasGroundedEvidence, isTrue);
    });

    test('missing evidence makes business health response clarification needed',
        () {
      final response = router.responseForIntent(
        AiCfoConversationIntent.businessHealth,
        context: const AiCfoContextSnapshot.empty(),
      );

      expect(response.type, AiCfoResponseType.clarificationNeeded);
      expect(response.evidence, isEmpty);
    });

    test('every generated evidence item has a source', () {
      final snapshot = builder.buildFromToolResults(
        financialSummary: FinancialToolResult.success({
          'totalIncome': 100.0,
          'totalProfit': 35.0,
          'totalExpenses': 65.0,
          'netCashFlow': 35.0,
          'accountsReceivable': 15.0,
          'profitMargin': 35.0,
        }),
        income: FinancialToolResult.success({
          'records': [
            {'id': 's-1'},
          ],
          'total': 100.0,
          'profit': 35.0,
          'count': 1,
        }),
        expenses: FinancialToolResult.success({
          'records': [
            {'id': 'e-1'},
          ],
          'total': 65.0,
          'count': 1,
        }),
        invoices: FinancialToolResult.success({
          'records': [
            {'id': 'i-1'},
          ],
          'totalAmount': 40.0,
          'totalPaid': 25.0,
          'outstanding': 15.0,
          'count': 1,
        }),
        customers: FinancialToolResult.success({
          'records': [
            {'id': 'c-1'},
          ],
          'totalOutstanding': 15.0,
          'count': 1,
        }),
        products: FinancialToolResult.success({
          'records': [
            {'id': 'p-1'},
          ],
          'totalValue': 120.0,
          'count': 1,
        }),
      );

      expect(
        snapshot
            .evidenceFor(AiCfoContextArea.businessHealth)
            .every((item) => item.source.trim().isNotEmpty),
        isTrue,
      );
    });

    test('snapshot builder uses read-only financial tool methods only',
        () async {
      final tools = _ReadOnlyFinancialTools();
      final service = AiCfoContextSnapshotBuilder(financialTools: tools);

      final snapshot = await service.buildFromFinancialTools(
        businessId: 'business-1',
        intent: AiCfoConversationIntent.businessHealth,
      );

      expect(snapshot.evidenceFor(AiCfoContextArea.businessHealth), isNotEmpty);
      expect(
          tools.readCalls,
          containsAll([
            'getFinancialSummary',
            'getInvoices',
            'getIncome',
            'getExpenses',
            'getProducts',
            'getCustomers',
          ]));
      expect(tools.writeCalls, isEmpty);
    });
  });
}

class _ReadOnlyFinancialTools extends FinancialTools {
  final List<String> readCalls = [];
  final List<String> writeCalls = [];

  @override
  Future<FinancialToolResult> getFinancialSummary({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    readCalls.add('getFinancialSummary');
    return FinancialToolResult.success({
      'totalIncome': 100.0,
      'totalProfit': 25.0,
      'totalExpenses': 75.0,
      'netCashFlow': 25.0,
      'accountsReceivable': 10.0,
      'profitMargin': 25.0,
    });
  }

  @override
  Future<FinancialToolResult> getIncome({
    required String businessId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    readCalls.add('getIncome');
    return FinancialToolResult.success({
      'records': [
        {'id': 'sale-1'},
      ],
      'total': 100.0,
      'profit': 25.0,
      'count': 1,
    });
  }

  @override
  Future<FinancialToolResult> getExpenses({
    required String businessId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    readCalls.add('getExpenses');
    return FinancialToolResult.success({
      'records': [
        {'id': 'expense-1'},
      ],
      'total': 75.0,
      'count': 1,
    });
  }

  @override
  Future<FinancialToolResult> getInvoices({
    required String businessId,
    String? status,
    int limit = 100,
  }) async {
    readCalls.add('getInvoices');
    return FinancialToolResult.success({
      'records': [
        {'id': 'invoice-1'},
      ],
      'totalAmount': 30.0,
      'totalPaid': 20.0,
      'outstanding': 10.0,
      'count': 1,
    });
  }

  @override
  Future<FinancialToolResult> getCustomers({
    required String businessId,
    String? searchQuery,
    int limit = 100,
  }) async {
    readCalls.add('getCustomers');
    return FinancialToolResult.success({
      'records': [
        {'id': 'customer-1'},
      ],
      'totalOutstanding': 10.0,
      'count': 1,
    });
  }

  @override
  Future<FinancialToolResult> getProducts({
    required String businessId,
    String? searchQuery,
    bool lowStockOnly = false,
    int limit = 100,
  }) async {
    readCalls.add('getProducts');
    return FinancialToolResult.success({
      'records': [
        {'id': 'product-1'},
      ],
      'totalValue': 50.0,
      'count': 1,
    });
  }
}
