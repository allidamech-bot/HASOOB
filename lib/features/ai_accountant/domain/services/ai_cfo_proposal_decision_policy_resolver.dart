import '../ai_cfo_conversation_response.dart';
import '../ai_cfo_evidence.dart';
import '../ai_cfo_proposal_decision_policy.dart';
import '../ai_cfo_proposal_lifecycle.dart';

class AiCfoProposalDecisionPolicyResolver {
  const AiCfoProposalDecisionPolicyResolver();

  AiCfoProposalDecisionResult resolve({
    required AiCfoProposalDecision decision,
    required AiCfoProposalLifecycle lifecycle,
  }) {
    if (!lifecycle.isSessionOnly) {
      return _denied(
        decision,
        'Proposal decision policy only accepts session lifecycle state.',
      );
    }

    if (decision == AiCfoProposalDecision.execute) {
      return _executeDecision(lifecycle);
    }

    if (!lifecycle.hasProposal) {
      return _noProposalDecision(decision);
    }

    if (decision == AiCfoProposalDecision.review) {
      return _allowed(
        decision,
        'Active proposal can be reviewed in the existing screen flow.',
        AiCfoResponseType.proposal,
      );
    }

    if (decision == AiCfoProposalDecision.approve) {
      return _allowed(
        decision,
        'Active proposal can continue through the existing approval flow.',
        AiCfoResponseType.proposal,
      );
    }

    return _allowed(
      decision,
      'Active proposal can be deferred as session-only follow-up.',
      AiCfoResponseType.followUp,
    );
  }

  AiCfoProposalDecisionResult _noProposalDecision(
    AiCfoProposalDecision decision,
  ) {
    switch (decision) {
      case AiCfoProposalDecision.review:
        return _denied(
          decision,
          'There is no active proposal to review.',
          AiCfoResponseType.clarificationNeeded,
        );
      case AiCfoProposalDecision.approve:
        return _denied(
          decision,
          'There is no active proposal to approve.',
          AiCfoResponseType.proposal,
        );
      case AiCfoProposalDecision.defer:
        return _denied(
          decision,
          'There is no active proposal to defer.',
        );
      case AiCfoProposalDecision.execute:
        return _denied(
          decision,
          'Execution requires an active proposal first. No financial record was changed.',
        );
    }
  }

  AiCfoProposalDecisionResult _executeDecision(
    AiCfoProposalLifecycle lifecycle,
  ) {
    if (lifecycle.isBlocked) {
      return _denied(
        AiCfoProposalDecision.execute,
        lifecycle.reason ??
            'Execution is blocked for the current proposal lifecycle.',
      );
    }
    if (lifecycle.state == AiCfoProposalLifecycleState.deferred) {
      return _denied(
        AiCfoProposalDecision.execute,
        'Deferred proposal state cannot auto-execute.',
      );
    }
    if (lifecycle.state == AiCfoProposalLifecycleState.failed) {
      return _denied(
        AiCfoProposalDecision.execute,
        'Failed proposal state cannot auto-execute.',
      );
    }
    if (lifecycle.state == AiCfoProposalLifecycleState.executed) {
      return _denied(
        AiCfoProposalDecision.execute,
        'Executed proposal state cannot repeat execution.',
      );
    }
    if (!lifecycle.hasProposal) {
      return _noProposalDecision(AiCfoProposalDecision.execute);
    }
    if (!lifecycle.canExecute) {
      return _denied(
        AiCfoProposalDecision.execute,
        'Execution is blocked until the active proposal is explicitly approved.',
      );
    }
    return _allowed(
      AiCfoProposalDecision.execute,
      'Policy allows handoff to the existing guarded execution path only.',
      AiCfoResponseType.executionResult,
    );
  }

  AiCfoProposalDecisionResult _allowed(
    AiCfoProposalDecision decision,
    String reason,
    AiCfoResponseType responseType,
  ) {
    return AiCfoProposalDecisionResult(
      decision: decision,
      allowed: true,
      reason: reason,
      responseType: responseType,
      confidence: AiCfoEvidenceConfidence.high,
    );
  }

  AiCfoProposalDecisionResult _denied(
    AiCfoProposalDecision decision,
    String reason, [
    AiCfoResponseType responseType = AiCfoResponseType.blocked,
  ]) {
    return AiCfoProposalDecisionResult(
      decision: decision,
      allowed: false,
      reason: reason,
      responseType: responseType,
      confidence: AiCfoEvidenceConfidence.high,
    );
  }
}
