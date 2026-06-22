import '../../data/models/ai_proposal_model.dart';
import '../ai_cfo_execution_outcome.dart';
import '../ai_cfo_proposal_state_event.dart';

class AiCfoExecutionOutcomeNormalizer {
  const AiCfoExecutionOutcomeNormalizer();

  AiCfoExecutionOutcome blocked({
    required AiProposalModel? proposal,
    required String reason,
    String? proposalSessionId,
  }) {
    return AiCfoExecutionOutcome(
      type: AiCfoExecutionOutcomeType.blocked,
      proposal: proposal,
      proposalSessionId: proposalSessionId,
      message: reason,
      reason: reason,
    );
  }

  AiCfoExecutionOutcome started({
    required AiProposalModel proposal,
    required String proposalSessionId,
  }) {
    return AiCfoExecutionOutcome(
      type: AiCfoExecutionOutcomeType.started,
      proposal: proposal,
      proposalSessionId: proposalSessionId,
      message: 'Existing execution path started.',
    );
  }

  AiCfoExecutionOutcome succeeded({
    required AiProposalModel proposal,
    required String proposalSessionId,
    required String message,
  }) {
    return AiCfoExecutionOutcome(
      type: AiCfoExecutionOutcomeType.succeeded,
      proposal: proposal,
      proposalSessionId: proposalSessionId,
      message: message,
      completedExternally: true,
      mutatedLedger: true,
      isSessionOnly: false,
    );
  }

  AiCfoExecutionOutcome failed({
    required AiProposalModel? proposal,
    required String reason,
    String? proposalSessionId,
  }) {
    return AiCfoExecutionOutcome(
      type: AiCfoExecutionOutcomeType.failed,
      proposal: proposal,
      proposalSessionId: proposalSessionId,
      message: reason,
      reason: reason,
    );
  }

  AiCfoExecutionOutcome skipped({
    required String reason,
    AiProposalModel? proposal,
    String? proposalSessionId,
  }) {
    return AiCfoExecutionOutcome(
      type: AiCfoExecutionOutcomeType.skipped,
      proposal: proposal,
      proposalSessionId: proposalSessionId,
      message: reason,
      reason: reason,
    );
  }

  AiCfoProposalStateEvent? toStateEventOrNull(
    AiCfoExecutionOutcome outcome,
  ) {
    final proposalId = outcome.proposalSessionId?.trim();
    final proposal = outcome.proposal;
    if ((proposalId == null || proposalId.isEmpty) && proposal == null) {
      return null;
    }

    final eventType = switch (outcome.type) {
      AiCfoExecutionOutcomeType.blocked => AiCfoProposalStateEventType.blocked,
      AiCfoExecutionOutcomeType.started =>
        AiCfoProposalStateEventType.executionStarted,
      AiCfoExecutionOutcomeType.succeeded =>
        AiCfoProposalStateEventType.executed,
      AiCfoExecutionOutcomeType.failed => AiCfoProposalStateEventType.failed,
      AiCfoExecutionOutcomeType.none ||
      AiCfoExecutionOutcomeType.skipped =>
        null,
    };
    if (eventType == null) return null;

    return AiCfoProposalStateEvent(
      type: eventType,
      proposal: proposal,
      proposalSessionId: proposalId,
      reason: outcome.reason ?? outcome.message,
      occurredAt: DateTime.now(),
      completedExternally: outcome.completedExternally,
      mutatesLedger: false,
    );
  }
}
