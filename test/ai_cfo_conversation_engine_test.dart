import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/data/tools/financial_tools.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_context_snapshot_builder.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_response.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_cfo_conversation_engine.dart';

void main() {
  group('AiCfoConversationEngine', () {
    test('blocks execute when there is no active proposal', () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'ظ†ظپط°',
        businessId: 'business-1',
      );

      expect(response, isNotNull);
      expect(response!.type, AiCfoResponseType.blocked);
      expect(response.isBlocked, isTrue);
      expect(response.canExecute, isFalse);
      expect(tools.readCalls, isEmpty);
      expect(tools.writeCalls, isEmpty);
    });

    test('returns approval response when no active proposal exists', () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'ظ…ظˆط§ظپظ‚',
        businessId: 'business-1',
      );

      expect(response, isNotNull);
      expect(response!.type, AiCfoResponseType.proposal);
      expect(response.isBlocked, isTrue);
      expect(response.canExecute, isFalse);
      expect(response.message, contains('no active proposal'));
      expect(tools.readCalls, isEmpty);
      expect(tools.writeCalls, isEmpty);
    });

    test('returns read-only business health response from snapshot evidence',
        () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'business health',
        businessId: 'business-1',
      );

      expect(response, isNotNull);
      expect(response!.type, AiCfoResponseType.answer);
      expect(response.evidence, isNotEmpty);
      expect(response.hasGroundedEvidence, isTrue);
      expect(tools.readCalls, contains('getFinancialSummary'));
      expect(tools.writeCalls, isEmpty);
    });

    test('returns clarificationNeeded when business id is missing', () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'business health',
        businessId: '',
      );

      expect(response, isNotNull);
      expect(response!.type, AiCfoResponseType.clarificationNeeded);
      expect(response.evidence, isEmpty);
      expect(tools.readCalls, isEmpty);
      expect(tools.writeCalls, isEmpty);
    });

    test('returns inventory response using FinancialTools.getProducts source',
        () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'inventory review',
        businessId: 'business-1',
      );

      expect(response, isNotNull);
      expect(response!.type, AiCfoResponseType.answer);
      expect(
        response.evidence.map((item) => item.source),
        everyElement('FinancialTools.getProducts'),
      );
      expect(tools.readCalls, ['getProducts']);
      expect(tools.writeCalls, isEmpty);
    });

    test('returns null for unsupported random input', () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'write a birthday poem',
        businessId: 'business-1',
      );

      expect(response, isNull);
      expect(tools.readCalls, isEmpty);
      expect(tools.writeCalls, isEmpty);
    });

    test('returns null for proposal creation flow', () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);

      final response = await engine.resolve(
        input: 'prepare purchase proposal',
        businessId: 'business-1',
      );

      expect(response, isNull);
      expect(tools.readCalls, isEmpty);
      expect(tools.writeCalls, isEmpty);
    });

    test('returns null for active proposal execution flow', () async {
      final tools = _EngineFinancialTools();
      final engine = _engineWith(tools);
      final proposal = AiProposalModel(
        actionType: 'sale',
        explanation: 'Existing proposal should stay in current execution flow.',
        confidenceScore: 0.9,
        inventoryPayload: const {'productId': 'p-1', 'quantity': 1},
        financialPayload: const {'totalAmount': 10.0},
      );

      final response = await engine.resolve(
        input: 'execute',
        businessId: 'business-1',
        activeProposal: proposal,
      );

      expect(response, isNull);
      expect(tools.readCalls, isEmpty);
      expect(tools.writeCalls, isEmpty);
    });

    test('engine does not require UI or BuildContext', () {
      final source = File(
        'lib/features/ai_accountant/domain/services/'
        'ai_cfo_conversation_engine.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('BuildContext')));
      expect(source, isNot(contains('material.dart')));
      expect(source, isNot(contains('widgets.dart')));
    });

    test('screen no longer owns read-only intent routing logic directly', () {
      final source = File(
        'lib/features/ai_accountant/presentation/screens/'
        'ai_accountant_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('_isReadOnlyKernelIntent')));
      expect(source, isNot(contains('buildFromFinancialTools')));
      expect(source, contains('AiCfoConversationEngine'));
    });
  });
}

AiCfoConversationEngine _engineWith(_EngineFinancialTools tools) {
  return AiCfoConversationEngine(
    snapshotBuilder: AiCfoContextSnapshotBuilder(financialTools: tools),
  );
}

class _EngineFinancialTools extends FinancialTools {
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
