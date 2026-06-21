import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_context_snapshot.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_intent.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_response.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_conversation_router.dart';
import 'package:hasoob_app/features/ai_accountant/domain/ai_cfo_evidence.dart';

void main() {
  const router = AiCfoConversationRouter();

  group('AiCfoConversationRouter', () {
    test('detects business health intent from Arabic', () {
      expect(
        router.classify('ظƒظٹظپ ظˆط¶ط¹ ط§ظ„ط´ط±ظƒط©طں'),
        AiCfoConversationIntent.businessHealth,
      );
      expect(
        router.classify('كيف وضع الشركة؟'),
        AiCfoConversationIntent.businessHealth,
      );
    });

    test('detects cashflow intent', () {
      expect(
        router.classify('ط±ط§ط¬ط¹ ط§ظ„ط³ظٹظˆظ„ط© ظˆط§ظ„ظƒط§ط´'),
        AiCfoConversationIntent.cashflowReview,
      );
      expect(
        router.classify('راجع السيولة والكاش'),
        AiCfoConversationIntent.cashflowReview,
      );
    });

    test('detects inventory intent', () {
      expect(
        router.classify('ظ‡ظ„ ط§ظ„ظ…ط®ط²ظˆظ† ط¹ظ†ط¯ظٹ ظپظٹظ‡ ظ…ط´ظƒظ„ط©طں'),
        AiCfoConversationIntent.inventoryReview,
      );
      expect(
        router.classify('هل المخزون عندي فيه مشكلة؟'),
        AiCfoConversationIntent.inventoryReview,
      );
    });

    test('handles unsupported requests', () {
      expect(
        router.classify('write a birthday poem about clouds'),
        AiCfoConversationIntent.unsupported,
      );
    });

    test('missing data response does not invent evidence or proposal', () {
      final response = router.respond(
        'كيف وضع الشركة؟',
        context: const AiCfoContextSnapshot.empty(),
      );

      expect(response.type, AiCfoResponseType.clarificationNeeded);
      expect(response.evidence, isEmpty);
      expect(response.proposal, isNull);
      expect(response.requiresApproval, isFalse);
      expect(response.message, contains('Data completeness'));
    });

    test('execution guard blocks execution when there is no active proposal',
        () {
      final response = router.respond(
        'ظ†ظپط°',
        context: const AiCfoContextSnapshot.empty(),
      );

      expect(response.type, AiCfoResponseType.blocked);
      expect(response.isBlocked, isTrue);
      expect(response.canExecute, isFalse);
      expect(response.message, isNot(contains('success')));
      expect(response.message, isNot(contains('finished')));
    });

    test('approval guard requires approval before execution', () {
      final proposal = AiProposalModel(
        actionType: 'sale',
        explanation: 'Review sale before posting.',
        confidenceScore: 0.84,
        inventoryPayload: const {'productId': 'p-1', 'quantity': 1},
        financialPayload: const {'totalAmount': 10.0},
      );

      final response = router.respond(
        'execute',
        context: const AiCfoContextSnapshot.empty(),
        activeProposal: proposal,
      );

      expect(response.type, AiCfoResponseType.blocked);
      expect(response.requiresApproval, isTrue);
      expect(response.canExecute, isFalse);
      expect(response.proposal, same(proposal));
    });

    test('evidence-first response contains sourced evidence', () {
      const snapshot = AiCfoContextSnapshot(
        inventorySummary: [
          AiCfoEvidence(
            label: 'Low stock products',
            value: '3',
            source: 'FinancialTools.getProducts',
            confidence: AiCfoEvidenceConfidence.high,
            explanation: 'Derived from product stock and threshold records.',
          ),
        ],
        salesSummary: [
          AiCfoEvidence(
            label: 'Recent sales records',
            value: '12',
            source: 'FinancialTools.getIncome',
            confidence: AiCfoEvidenceConfidence.medium,
            explanation: 'Derived from sales records returned by the tool.',
          ),
        ],
        dataCompletenessNotes: ['Receivables were not included.'],
      );

      final response = router.respond(
        'هل المخزون عندي فيه مشكلة؟',
        context: snapshot,
      );

      expect(response.type, AiCfoResponseType.answer);
      expect(response.evidence, isNotEmpty);
      expect(response.evidence.every((item) => item.source.isNotEmpty), isTrue);
      expect(response.message, isNot(contains('unsupported')));
    });
  });
}
