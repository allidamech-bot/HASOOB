import '../ai_cfo_proposal_session_state.dart';
import '../ai_cfo_proposal_state_event.dart';

class AiCfoProposalStateReducer {
  const AiCfoProposalStateReducer();

  AiCfoProposalSessionState reduce({
    required AiCfoProposalSessionState state,
    required AiCfoProposalStateEvent event,
  }) {
    final proposalId = _proposalId(event);
    if (event.type == AiCfoProposalStateEventType.cleared) {
      return _clear(state, proposalId);
    }
    if (proposalId == null || proposalId.trim().isEmpty) return state;

    return switch (event.type) {
      AiCfoProposalStateEventType.reviewed => state.copyWith(
          reviewedProposalIds: {...state.reviewedProposalIds, proposalId},
        ),
      AiCfoProposalStateEventType.approved => state.copyWith(
          approvedProposalIds: {...state.approvedProposalIds, proposalId},
        ),
      AiCfoProposalStateEventType.deferred => state.copyWith(
          deferredProposalIds: {...state.deferredProposalIds, proposalId},
        ),
      AiCfoProposalStateEventType.executionStarted => state,
      AiCfoProposalStateEventType.executed => event.completedExternally
          ? state.copyWith(
              executedProposalIds: {...state.executedProposalIds, proposalId},
            )
          : state,
      AiCfoProposalStateEventType.failed => state.copyWith(
          failureReasons: {
            ...state.failureReasons,
            proposalId: event.reason,
          },
        ),
      AiCfoProposalStateEventType.blocked => state.copyWith(
          blockedReasons: {
            ...state.blockedReasons,
            proposalId: event.reason,
          },
        ),
      AiCfoProposalStateEventType.cleared => state,
    };
  }

  String? _proposalId(AiCfoProposalStateEvent event) {
    final explicitId = event.proposalSessionId?.trim();
    if (explicitId != null && explicitId.isNotEmpty) return explicitId;
    final proposal = event.proposal;
    if (proposal == null) return null;
    return identityHashCode(proposal).toString();
  }

  AiCfoProposalSessionState _clear(
    AiCfoProposalSessionState state,
    String? proposalId,
  ) {
    if (proposalId == null || proposalId.trim().isEmpty) {
      return AiCfoProposalSessionState.empty();
    }

    return state.copyWith(
      reviewedProposalIds: state.reviewedProposalIds
          .where((candidate) => candidate != proposalId)
          .toSet(),
      deferredProposalIds: state.deferredProposalIds
          .where((candidate) => candidate != proposalId)
          .toSet(),
      approvedProposalIds: state.approvedProposalIds
          .where((candidate) => candidate != proposalId)
          .toSet(),
      executedProposalIds: state.executedProposalIds
          .where((candidate) => candidate != proposalId)
          .toSet(),
      blockedReasons: Map<String, String>.from(state.blockedReasons)
        ..remove(proposalId),
      failureReasons: Map<String, String>.from(state.failureReasons)
        ..remove(proposalId),
    );
  }
}
