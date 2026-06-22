import '../../data/models/ai_proposal_model.dart';
import '../ai_cfo_context_snapshot.dart';
import '../ai_cfo_context_snapshot_builder.dart';
import '../ai_cfo_conversation_intent.dart';
import '../ai_cfo_conversation_response.dart';
import '../ai_cfo_conversation_router.dart';
import '../ai_cfo_proposal_decision_policy.dart';
import '../ai_cfo_proposal_lifecycle.dart';
import 'ai_cfo_proposal_decision_policy_resolver.dart';

class AiCfoConversationEngine {
  const AiCfoConversationEngine({
    AiCfoConversationRouter router = const AiCfoConversationRouter(),
    AiCfoContextSnapshotBuilder snapshotBuilder =
        const AiCfoContextSnapshotBuilder(),
    AiCfoProposalDecisionPolicyResolver decisionPolicyResolver =
        const AiCfoProposalDecisionPolicyResolver(),
  })  : _router = router,
        _snapshotBuilder = snapshotBuilder,
        _decisionPolicyResolver = decisionPolicyResolver;

  final AiCfoConversationRouter _router;
  final AiCfoContextSnapshotBuilder _snapshotBuilder;
  final AiCfoProposalDecisionPolicyResolver _decisionPolicyResolver;

  Future<AiCfoConversationResponse?> resolve({
    required String input,
    required String businessId,
    AiProposalModel? activeProposal,
    AiCfoProposalLifecycle? lifecycle,
    bool hasApprovedProposal = false,
  }) async {
    final actionProposal = activeProposal ??
        lifecycle?.activeProposal ??
        lifecycle?.confirmationProposal;
    final intent = _router.classify(
      input,
      activeProposal: actionProposal,
      hasApprovedProposal: hasApprovedProposal,
    );

    final decision = _proposalDecisionForIntent(intent);
    if (decision != null && lifecycle != null) {
      final policyResult = _decisionPolicyResolver.resolve(
        decision: decision,
        lifecycle: lifecycle,
      );
      if (_shouldReturnPolicyGuard(
        intent: intent,
        proposal: actionProposal,
        lifecycle: lifecycle,
        policyResult: policyResult,
      )) {
        return _policyGuardResponse(
          intent: intent,
          proposal: actionProposal,
          result: policyResult,
        );
      }
    } else if (_shouldGuardWithoutActiveProposal(intent, actionProposal)) {
      final policyResult = _decisionPolicyResolver.resolve(
        decision: decision!,
        lifecycle: const AiCfoProposalLifecycle(),
      );
      return _policyGuardResponse(
        intent: intent,
        proposal: actionProposal,
        result: policyResult,
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
        activeProposal: actionProposal,
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

  bool _shouldReturnPolicyGuard({
    required AiCfoConversationIntent intent,
    required AiProposalModel? proposal,
    required AiCfoProposalLifecycle lifecycle,
    required AiCfoProposalDecisionResult policyResult,
  }) {
    if (policyResult.allowed) return false;
    if (proposal == null) return true;
    if (intent != AiCfoConversationIntent.executeProposal) return false;
    return lifecycle.isBlocked ||
        lifecycle.state == AiCfoProposalLifecycleState.deferred ||
        lifecycle.state == AiCfoProposalLifecycleState.failed ||
        lifecycle.state == AiCfoProposalLifecycleState.executed;
  }

  AiCfoConversationResponse _policyGuardResponse({
    required AiCfoConversationIntent intent,
    required AiProposalModel? proposal,
    required AiCfoProposalDecisionResult result,
  }) {
    return AiCfoConversationResponse(
      type: result.responseType,
      intent: intent,
      title: _policyGuardTitle(result),
      message: result.reason,
      proposal: proposal,
      requiresApproval: intent == AiCfoConversationIntent.approveProposal ||
          intent == AiCfoConversationIntent.executeProposal,
      isBlocked: result.denied,
      blockedReason: result.denied ? result.reason : null,
      sessionOnly: true,
      canExecute: false,
    );
  }

  String _policyGuardTitle(AiCfoProposalDecisionResult result) {
    if (result.allowed) return 'Proposal decision';
    return switch (result.decision) {
      AiCfoProposalDecision.review => 'Review unavailable',
      AiCfoProposalDecision.approve => 'Approval required',
      AiCfoProposalDecision.defer => 'Defer proposal',
      AiCfoProposalDecision.execute => 'Execution blocked',
    };
  }

  AiCfoProposalDecision? _proposalDecisionForIntent(
    AiCfoConversationIntent intent,
  ) {
    return switch (intent) {
      AiCfoConversationIntent.approveProposal => AiCfoProposalDecision.approve,
      AiCfoConversationIntent.executeProposal => AiCfoProposalDecision.execute,
      AiCfoConversationIntent.deferProposal => AiCfoProposalDecision.defer,
      _ => null,
    };
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
