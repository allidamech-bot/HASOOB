import '../../data/models/ai_proposal_model.dart';
import '../ai_cfo_proposal_lifecycle.dart';

class AiCfoProposalLifecycleResolver {
  const AiCfoProposalLifecycleResolver();

  String proposalSessionId(AiProposalModel proposal) {
    return identityHashCode(proposal).toString();
  }

  AiCfoProposalLifecycle resolve({
    AiProposalModel? activeProposal,
    AiProposalModel? confirmationProposal,
    Set<String> reviewedProposalIds = const {},
    Set<String> approvedProposalIds = const {},
    List<String> deferredFollowUps = const [],
    bool isExecuting = false,
    bool lastExecutionSucceeded = false,
    bool lastExecutionFailed = false,
    String? reason,
  }) {
    final state = _resolveState(
      activeProposal: activeProposal,
      confirmationProposal: confirmationProposal,
      reviewedProposalIds: reviewedProposalIds,
      approvedProposalIds: approvedProposalIds,
      deferredFollowUps: deferredFollowUps,
      isExecuting: isExecuting,
      lastExecutionSucceeded: lastExecutionSucceeded,
      lastExecutionFailed: lastExecutionFailed,
      reason: reason,
    );

    return AiCfoProposalLifecycle(
      activeProposal: activeProposal,
      confirmationProposal: confirmationProposal,
      reviewedProposalIds: Set.unmodifiable(reviewedProposalIds),
      approvedProposalIds: Set.unmodifiable(approvedProposalIds),
      deferredFollowUps: List.unmodifiable(deferredFollowUps),
      state: state,
      reason: reason,
    );
  }

  AiCfoProposalLifecycleState _resolveState({
    required AiProposalModel? activeProposal,
    required AiProposalModel? confirmationProposal,
    required Set<String> reviewedProposalIds,
    required Set<String> approvedProposalIds,
    required List<String> deferredFollowUps,
    required bool isExecuting,
    required bool lastExecutionSucceeded,
    required bool lastExecutionFailed,
    required String? reason,
  }) {
    if (reason != null && reason.trim().isNotEmpty) {
      return AiCfoProposalLifecycleState.blocked;
    }
    if (isExecuting) return AiCfoProposalLifecycleState.executing;
    if (lastExecutionSucceeded) return AiCfoProposalLifecycleState.executed;
    if (lastExecutionFailed) return AiCfoProposalLifecycleState.failed;
    if (confirmationProposal != null) {
      return AiCfoProposalLifecycleState.awaitingApproval;
    }
    if (activeProposal != null) {
      final sessionId = proposalSessionId(activeProposal);
      if (deferredFollowUps.contains(sessionId)) {
        return AiCfoProposalLifecycleState.deferred;
      }
      if (approvedProposalIds.contains(sessionId)) {
        return AiCfoProposalLifecycleState.approved;
      }
      if (reviewedProposalIds.contains(sessionId)) {
        return AiCfoProposalLifecycleState.reviewed;
      }
      return AiCfoProposalLifecycleState.awaitingReview;
    }
    if (deferredFollowUps.isNotEmpty) {
      return AiCfoProposalLifecycleState.deferred;
    }
    return AiCfoProposalLifecycleState.none;
  }
}
