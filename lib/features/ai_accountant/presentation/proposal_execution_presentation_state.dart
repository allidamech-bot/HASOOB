import '../data/models/ai_proposal_model.dart';
import '../domain/ai_cfo_proposal_session_state.dart';

enum AiCfoProposalExecutionUxState {
  unsupported,
  reviewOnly,
  awaitingApproval,
  ready,
  executing,
  deferred,
  blocked,
  failed,
  executed,
}

class AiCfoProposalExecutionPresentationState {
  final AiCfoProposalExecutionUxState state;
  final String statusLabel;
  final String decisionLabel;
  final String executionLabel;
  final bool canDelegateExecution;

  const AiCfoProposalExecutionPresentationState({
    required this.state,
    required this.statusLabel,
    required this.decisionLabel,
    required this.executionLabel,
    required this.canDelegateExecution,
  });

  bool get isTerminal =>
      state == AiCfoProposalExecutionUxState.executed ||
      state == AiCfoProposalExecutionUxState.failed ||
      state == AiCfoProposalExecutionUxState.blocked;

  static AiCfoProposalExecutionPresentationState resolve({
    required AiProposalModel proposal,
    required String proposalSessionId,
    required AiCfoProposalSessionState sessionState,
    required bool isCurrent,
    bool requiresConfirmation = false,
    required bool isExecuting,
  }) {
    if (sessionState.isExecuted(proposalSessionId)) {
      return const AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.executed,
        statusLabel: 'Executed',
        decisionLabel: 'Executed by the guarded external execution path',
        executionLabel: 'Executed after confirmed completion',
        canDelegateExecution: false,
      );
    }

    if (sessionState.isBlocked(proposalSessionId)) {
      return AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.blocked,
        statusLabel: 'Blocked',
        decisionLabel: sessionState.blockedReasons[proposalSessionId] ??
            'Execution is blocked pending follow-up.',
        executionLabel: 'Blocked - not executed',
        canDelegateExecution: false,
      );
    }

    if (sessionState.isFailed(proposalSessionId)) {
      return AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.failed,
        statusLabel: 'Failed',
        decisionLabel: sessionState.failureReasons[proposalSessionId] ??
            'Execution failed and needs follow-up.',
        executionLabel: 'Failed - not executed',
        canDelegateExecution: false,
      );
    }

    if (sessionState.isDeferred(proposalSessionId)) {
      return const AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.deferred,
        statusLabel: 'Deferred',
        decisionLabel: 'Deferred in this session - not ready to execute',
        executionLabel: 'Deferred - not executed',
        canDelegateExecution: false,
      );
    }

    if (isExecuting) {
      return const AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.executing,
        statusLabel: 'Executing',
        decisionLabel: 'Execution is in progress through the guarded path',
        executionLabel: 'Running - waiting for external result',
        canDelegateExecution: false,
      );
    }

    if (!isCurrent) {
      return const AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.reviewOnly,
        statusLabel: 'Review only',
        decisionLabel: 'Historical card: review only',
        executionLabel: 'Execution state unavailable on this session card',
        canDelegateExecution: false,
      );
    }

    if (requiresConfirmation) {
      return const AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.awaitingApproval,
        statusLabel: 'Awaiting confirmation',
        decisionLabel: 'User confirmation required before execution',
        executionLabel: 'Confirmation needed - not executed',
        canDelegateExecution: false,
      );
    }

    if (!_isSupportedProposal(proposal)) {
      return const AiCfoProposalExecutionPresentationState(
        state: AiCfoProposalExecutionUxState.unsupported,
        statusLabel: 'Review only',
        decisionLabel: 'Execution is not wired for this action',
        executionLabel: 'Not executable by the guarded path',
        canDelegateExecution: false,
      );
    }

    final isPricing = proposal.actionType == 'pricing_simulation';
    return AiCfoProposalExecutionPresentationState(
      state: AiCfoProposalExecutionUxState.ready,
      statusLabel: 'Active',
      decisionLabel: isPricing
          ? 'Decision required: save simulation or keep reviewing'
          : 'Decision required: approve guarded execution or dismiss',
      executionLabel: 'Not executed yet',
      canDelegateExecution: true,
    );
  }

  static bool _isSupportedProposal(AiProposalModel proposal) {
    return proposal.actionType == 'purchase' ||
        proposal.actionType == 'sale' ||
        proposal.actionType == 'pricing_simulation';
  }
}
