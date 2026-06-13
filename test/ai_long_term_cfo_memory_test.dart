import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/features/ai_accountant/data/tools/financial_tools.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_business_memory.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_business_memory_manager.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_conversation_orchestrator.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_snapshot.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_insight_generator.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_risk_detector.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('Long term CFO memory', () {
    test('stores memory with required evidence fields', () {
      final manager = AiBusinessMemoryManager();
      final stored = manager.rememberLongTerm(AiCfoMemoryItem(
        id: 'mem-1',
        category: AiCfoMemoryCategory.financial,
        summary: 'You had a similar cash reserve risk previously.',
        source: 'AI Financial Snapshot',
        sourceType: 'financial_snapshot',
        timestamp: DateTime(2026, 1, 1),
        confidence: AiEvidenceConfidence.medium,
        relatedEntity: 'cashflow',
        evidenceReferences: const ['pending invoices 1000'],
      ));

      expect(stored, isTrue);
      final memory = manager.memory.longTermMemories.single;
      expect(memory.id, 'mem-1');
      expect(memory.category, AiCfoMemoryCategory.financial);
      expect(memory.source, 'AI Financial Snapshot');
      expect(memory.sourceType, 'financial_snapshot');
      expect(memory.timestamp, DateTime(2026, 1, 1));
      expect(memory.confidence, AiEvidenceConfidence.medium);
      expect(memory.evidenceReferences, contains('pending invoices 1000'));
    });

    test('retrieves relevant customer memory from customer risk analysis', () {
      final manager = AiBusinessMemoryManager();

      manager.extractFromAnalysis(
        plan: _customerPlan,
        evidence: _customerEvidence(),
        timestamp: DateTime(2026, 1, 2),
      );

      final memories = manager.retrieveRelevant(
        intent: AiAccountantIntent.customerBalanceAnalysis,
        userText: 'Is Slow Buyer risky?',
        relatedEntity: 'Slow Buyer',
      );

      expect(memories, hasLength(1));
      expect(memories.single.category, AiCfoMemoryCategory.customer);
      expect(memories.single.summary, contains('delayed payments before'));
      expect(memories.single.relatedEntity, 'Slow Buyer');
    });

    test('retrieves relevant financial risk memory', () {
      final manager = AiBusinessMemoryManager();
      final snapshot = AiFinancialSnapshot.fromEvidence(_overviewEvidence());
      final risks = AiRiskDetector().detect(snapshot);

      manager.extractFromAnalysis(
        plan: _overviewPlan,
        evidence: _overviewEvidence(),
        snapshot: snapshot,
        risks: risks,
        recommendations: AiInsightGenerator().generateRecommendations(
          snapshot: snapshot,
          risks: risks,
        ),
        timestamp: DateTime(2026, 1, 3),
      );

      final memories = manager.retrieveRelevant(
        intent: AiAccountantIntent.cashFlowAnalysis,
        userText: 'Do we have cashflow risk?',
      );

      expect(memories.map((memory) => memory.category),
          contains(AiCfoMemoryCategory.financial));
      expect(memories.map((memory) => memory.summary).join(' '),
          contains('cash reserve risk'));
    });

    test('avoids duplicate memory for repeated event', () {
      final manager = AiBusinessMemoryManager();

      manager.extractFromAnalysis(
        plan: _customerPlan,
        evidence: _customerEvidence(),
        timestamp: DateTime(2026, 1, 4),
      );
      manager.extractFromAnalysis(
        plan: _customerPlan,
        evidence: _customerEvidence(),
        timestamp: DateTime(2026, 1, 5),
      );

      expect(manager.memory.longTermMemories, hasLength(1));
    });

    test('memory appears in AI response context on later answer', () async {
      BusinessContext.initialize(
        businessId: 'g4-business',
        userId: 'g4-user',
        role: 'owner',
      );
      final orchestrator = AiConversationOrchestrator(
        financialTools: _FakeMemoryFinancialTools(),
      );

      final first = await orchestrator.generateResponse(
        userText: 'Which customers are becoming risky?',
      );
      final second = await orchestrator.generateResponse(
        userText: 'Review customer risk again',
      );

      expect(first.text, isNot(contains('Relevant Memory:')));
      expect(second.text, contains('Relevant Memory:'));
      expect(second.text, contains('Slow Buyer has delayed payments before'));
      expect(second.text, contains('Customer Credit Intelligence'));
    });
  });
}

class _FakeMemoryFinancialTools extends FinancialTools {
  @override
  Future<FinancialToolResult> getCustomers({
    required String businessId,
    String? searchQuery,
    int limit = 100,
  }) async {
    return FinancialToolResult.success({
      'totalOutstanding': 8500,
      'count': 1,
      'records': [
        {
          'id': 'c-slow',
          'name': 'Slow Buyer',
          'outstanding_balance': 8500,
        },
      ],
    });
  }

  @override
  Future<FinancialToolResult> getInvoices({
    required String businessId,
    String? status,
    int limit = 100,
  }) async {
    return FinancialToolResult.success({
      'outstanding': 8500,
      'count': 2,
      'records': [
        {
          'id': 'i-1',
          'customer_id': 'c-slow',
          'customer_name': 'Slow Buyer',
          'status': 'overdue',
          'total': 5000,
          'paid_amount': 0,
          'remaining_amount': 5000,
          'due_date': DateTime.now()
              .subtract(const Duration(days: 40))
              .toIso8601String(),
        },
        {
          'id': 'i-2',
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
}

AiEvidenceBundle _customerEvidence() {
  return AiEvidenceBundle.fromToolResults(
    plan: _customerPlan,
    tools: [
      const AiExecutedToolEvidence(
        toolName: 'getCustomers',
        success: true,
        reason: 'Review customer balances and receivables exposure.',
        data: {
          'totalOutstanding': 8500,
          'count': 1,
          'records': [
            {
              'id': 'c-slow',
              'name': 'Slow Buyer',
              'outstanding_balance': 8500,
            },
          ],
        },
      ),
      AiExecutedToolEvidence(
        toolName: 'getInvoices',
        success: true,
        reason:
            'Review invoice history, overdue frequency, and payment delays.',
        data: {
          'outstanding': 8500,
          'count': 2,
          'records': [
            {
              'id': 'i-1',
              'customer_id': 'c-slow',
              'customer_name': 'Slow Buyer',
              'status': 'overdue',
              'total': 5000,
              'paid_amount': 0,
              'remaining_amount': 5000,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 40))
                  .toIso8601String(),
            },
            {
              'id': 'i-2',
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
        },
      ),
    ],
  );
}

AiEvidenceBundle _overviewEvidence() {
  return AiEvidenceBundle.fromToolResults(
    plan: _overviewPlan,
    tools: [
      const AiExecutedToolEvidence(
        toolName: 'getFinancialSummary',
        success: true,
        reason: 'summary',
        data: {
          'totalIncome': 1000,
          'totalExpenses': 500,
          'totalProfit': 500,
          'accountsReceivable': 1200,
        },
      ),
      AiExecutedToolEvidence(
        toolName: 'getInvoices',
        success: true,
        reason: 'invoices',
        data: {
          'outstanding': 1200,
          'records': [
            {
              'status': 'overdue',
              'remaining_amount': 1200,
              'due_date': DateTime.now()
                  .subtract(const Duration(days: 10))
                  .toIso8601String(),
            },
          ],
        },
      ),
      const AiExecutedToolEvidence(
        toolName: 'getProducts',
        success: true,
        reason: 'products',
        data: {'records': []},
      ),
      const AiExecutedToolEvidence(
        toolName: 'getCustomers',
        success: true,
        reason: 'customers',
        data: {'totalOutstanding': 1200, 'records': []},
      ),
    ],
  );
}

const _customerPlan = AiToolPlan(
  intent: AiAccountantIntent.customerBalanceAnalysis,
  requiresTools: true,
  steps: [
    AiToolStep(
      toolName: 'getCustomers',
      reason: 'Review customer balances and receivables exposure.',
      required: true,
    ),
    AiToolStep(
      toolName: 'getInvoices',
      reason: 'Review invoice history, overdue frequency, and payment delays.',
      required: true,
    ),
  ],
  missingInputs: [],
  safetyLevel: AiToolSafetyLevel.readOnly,
);

const _overviewPlan = AiToolPlan(
  intent: AiAccountantIntent.financialOverview,
  requiresTools: true,
  steps: [
    AiToolStep(
      toolName: 'getFinancialSummary',
      reason: 'summary',
      required: true,
    ),
    AiToolStep(
      toolName: 'getInvoices',
      reason: 'invoices',
      required: false,
    ),
    AiToolStep(
      toolName: 'getProducts',
      reason: 'products',
      required: false,
    ),
    AiToolStep(
      toolName: 'getCustomers',
      reason: 'customers',
      required: false,
    ),
  ],
  missingInputs: [],
  safetyLevel: AiToolSafetyLevel.readOnly,
);
