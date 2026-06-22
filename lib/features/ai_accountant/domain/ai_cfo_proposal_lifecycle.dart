import '../data/models/ai_proposal_model.dart';

enum AiCfoProposalLifecycleState {
  none,
  draft,
  awaitingReview,
  reviewed,
  awaitingApproval,
  approved,
  executing,
  executed,
  failed,
  blocked,
  deferred,
  dismissed,
}

class AiCfoProposalLifecycle {
  final AiProposalModel? activeProposal;
  final AiProposalModel? confirmationProposal;
  final Set<String> reviewedProposalIds;
  final Set<String> approvedProposalIds;
  final List<String> deferredFollowUps;
  final AiCfoProposalLifecycleState state;
  final String? reason;

  const AiCfoProposalLifecycle({
    this.activeProposal,
    this.confirmationProposal,
    this.reviewedProposalIds = const {},
    this.approvedProposalIds = const {},
    this.deferredFollowUps = const [],
    this.state = AiCfoProposalLifecycleState.none,
    this.reason,
  });

  bool get hasActiveProposal => activeProposal != null;
  bool get hasConfirmationProposal => confirmationProposal != null;
  bool get hasProposal => hasActiveProposal || hasConfirmationProposal;

  bool get requiresApproval {
    if (!hasProposal) return false;
    return state == AiCfoProposalLifecycleState.awaitingReview ||
        state == AiCfoProposalLifecycleState.reviewed ||
        state == AiCfoProposalLifecycleState.awaitingApproval ||
        state == AiCfoProposalLifecycleState.approved;
  }

  bool get canExecute {
    if (!hasProposal) return false;
    return state == AiCfoProposalLifecycleState.reviewed ||
        state == AiCfoProposalLifecycleState.awaitingApproval ||
        state == AiCfoProposalLifecycleState.approved;
  }

  bool get isBlocked => state == AiCfoProposalLifecycleState.blocked;
  bool get isSessionOnly => true;
}
