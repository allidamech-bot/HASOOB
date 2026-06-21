import '../../data/models/ai_proposal_model.dart';
import '../ai_cfo_context_snapshot.dart';
import '../ai_cfo_context_snapshot_builder.dart';
import '../ai_cfo_conversation_intent.dart';
import '../ai_cfo_conversation_response.dart';
import '../ai_cfo_conversation_router.dart';

class AiCfoConversationEngine {
  const AiCfoConversationEngine({
    AiCfoConversationRouter router = const AiCfoConversationRouter(),
    AiCfoContextSnapshotBuilder snapshotBuilder =
        const AiCfoContextSnapshotBuilder(),
  })  : _router = router,
        _snapshotBuilder = snapshotBuilder;

  final AiCfoConversationRouter _router;
  final AiCfoContextSnapshotBuilder _snapshotBuilder;

  Future<AiCfoConversationResponse?> resolve({
    required String input,
    required String businessId,
    AiProposalModel? activeProposal,
    bool hasApprovedProposal = false,
  }) async {
    final intent = _router.classify(
      input,
      activeProposal: activeProposal,
      hasApprovedProposal: hasApprovedProposal,
    );

    if (_shouldGuardWithoutActiveProposal(intent, activeProposal)) {
      return _router.responseForIntent(
        intent,
        context: const AiCfoContextSnapshot.empty(),
        activeProposal: activeProposal,
        hasApprovedProposal: hasApprovedProposal,
      );
    }

    if (_isReadOnlyAnalysisIntent(intent)) {
      final snapshot = businessId.isEmpty
          ? const AiCfoContextSnapshot.empty()
          : await _snapshotBuilder.buildFromFinancialTools(
              businessId: businessId,
              intent: intent,
            );
      return _router.responseForIntent(
        intent,
        context: snapshot,
        activeProposal: activeProposal,
        hasApprovedProposal: hasApprovedProposal,
      );
    }

    return null;
  }

  bool _shouldGuardWithoutActiveProposal(
    AiCfoConversationIntent intent,
    AiProposalModel? activeProposal,
  ) {
    if (activeProposal != null) return false;
    return intent == AiCfoConversationIntent.executeProposal ||
        intent == AiCfoConversationIntent.deferProposal ||
        intent == AiCfoConversationIntent.approveProposal;
  }

  bool _isReadOnlyAnalysisIntent(AiCfoConversationIntent intent) {
    return intent == AiCfoConversationIntent.businessHealth ||
        intent == AiCfoConversationIntent.cashflowReview ||
        intent == AiCfoConversationIntent.inventoryReview ||
        intent == AiCfoConversationIntent.profitReview ||
        intent == AiCfoConversationIntent.receivablesReview ||
        intent == AiCfoConversationIntent.explainEvidence;
  }
}
