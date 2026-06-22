import '../../data/models/ai_proposal_model.dart';
import '../ai_cfo_conversation_intent.dart';
import '../ai_cfo_conversation_response.dart';
import '../ai_cfo_proposal_command.dart';
import '../ai_cfo_proposal_decision_policy.dart';
import '../ai_cfo_proposal_lifecycle.dart';
import 'ai_cfo_proposal_decision_policy_resolver.dart';

class AiCfoProposalCommandAdapter {
  const AiCfoProposalCommandAdapter({
    AiCfoProposalDecisionPolicyResolver decisionPolicyResolver =
        const AiCfoProposalDecisionPolicyResolver(),
  }) : _decisionPolicyResolver = decisionPolicyResolver;

  final AiCfoProposalDecisionPolicyResolver _decisionPolicyResolver;

  AiCfoProposalCommand adapt({
    required AiCfoConversationIntent intent,
    required AiCfoProposalLifecycle lifecycle,
    AiCfoConversationResponse? response,
    AiProposalModel? activeProposal,
  }) {
    final proposal = activeProposal ??
        lifecycle.activeProposal ??
        lifecycle.confirmationProposal;

    if (response?.isBlocked == true) {
      return _guard(
        reason: response!.blockedReason ?? response.message,
        response: response,
        proposal: proposal,
      );
    }

    final decision = _decisionForIntent(intent);
    if (decision == null) return _none();

    final policyResult = _decisionPolicyResolver.resolve(
      decision: decision,
      lifecycle: lifecycle,
    );

    if (proposal == null) {
      return response == null
          ? _none()
          : _guard(
              reason: policyResult.reason,
              response: response,
              proposal: proposal,
            );
    }

    if (!policyResult.allowed) {
      return _guard(reason: policyResult.reason, proposal: proposal);
    }

    return switch (decision) {
      AiCfoProposalDecision.review => AiCfoProposalCommand(
          type: AiCfoProposalCommandType.reviewProposal,
          proposal: proposal,
          reason: policyResult.reason,
          requiresScreenAction: true,
        ),
      AiCfoProposalDecision.approve => AiCfoProposalCommand(
          type: AiCfoProposalCommandType.approveProposal,
          proposal: proposal,
          reason: policyResult.reason,
          requiresScreenAction: true,
        ),
      AiCfoProposalDecision.defer => AiCfoProposalCommand(
          type: AiCfoProposalCommandType.deferProposal,
          proposal: proposal,
          reason: policyResult.reason,
          requiresScreenAction: true,
        ),
      AiCfoProposalDecision.execute => AiCfoProposalCommand(
          type: AiCfoProposalCommandType.executeProposal,
          proposal: proposal,
          reason: policyResult.reason,
          requiresScreenAction: true,
          canMutateLedger: true,
          isSessionOnly: false,
        ),
    };
  }

  AiCfoProposalDecision? _decisionForIntent(AiCfoConversationIntent intent) {
    return switch (intent) {
      AiCfoConversationIntent.createProposal => AiCfoProposalDecision.review,
      AiCfoConversationIntent.approveProposal => AiCfoProposalDecision.approve,
      AiCfoConversationIntent.deferProposal => AiCfoProposalDecision.defer,
      AiCfoConversationIntent.executeProposal => AiCfoProposalDecision.execute,
      _ => null,
    };
  }

  AiCfoProposalCommand _none() {
    return const AiCfoProposalCommand(type: AiCfoProposalCommandType.none);
  }

  AiCfoProposalCommand _guard({
    required String reason,
    AiCfoConversationResponse? response,
    AiProposalModel? proposal,
  }) {
    return AiCfoProposalCommand(
      type: AiCfoProposalCommandType.showGuardMessage,
      proposal: proposal,
      response: response,
      reason: reason,
      requiresScreenAction: true,
    );
  }
}
