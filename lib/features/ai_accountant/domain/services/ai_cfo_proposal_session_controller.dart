import '../../data/models/ai_proposal_model.dart';
import '../ai_cfo_conversation_intent.dart';
import '../ai_cfo_execution_outcome.dart';
import '../ai_cfo_proposal_command.dart';
import '../ai_cfo_proposal_lifecycle.dart';
import '../ai_cfo_proposal_session_controller_result.dart';
import '../ai_cfo_proposal_session_state.dart';
import '../ai_cfo_proposal_state_event.dart';
import 'ai_cfo_conversation_engine.dart';
import 'ai_cfo_execution_outcome_normalizer.dart';
import 'ai_cfo_proposal_command_adapter.dart';
import 'ai_cfo_proposal_lifecycle_resolver.dart';
import 'ai_cfo_proposal_state_reducer.dart';

class AiCfoProposalSessionController {
  const AiCfoProposalSessionController({
    AiCfoConversationEngine conversationEngine =
        const AiCfoConversationEngine(),
    AiCfoProposalLifecycleResolver lifecycleResolver =
        const AiCfoProposalLifecycleResolver(),
    AiCfoProposalCommandAdapter commandAdapter =
        const AiCfoProposalCommandAdapter(),
    AiCfoProposalStateReducer stateReducer = const AiCfoProposalStateReducer(),
    AiCfoExecutionOutcomeNormalizer outcomeNormalizer =
        const AiCfoExecutionOutcomeNormalizer(),
  })  : _conversationEngine = conversationEngine,
        _lifecycleResolver = lifecycleResolver,
        _commandAdapter = commandAdapter,
        _stateReducer = stateReducer,
        _outcomeNormalizer = outcomeNormalizer;

  final AiCfoConversationEngine _conversationEngine;
  final AiCfoProposalLifecycleResolver _lifecycleResolver;
  final AiCfoProposalCommandAdapter _commandAdapter;
  final AiCfoProposalStateReducer _stateReducer;
  final AiCfoExecutionOutcomeNormalizer _outcomeNormalizer;

  String proposalSessionId(AiProposalModel proposal) {
    return _lifecycleResolver.proposalSessionId(proposal);
  }

  AiCfoConversationIntent classifyIntent({
    required String input,
    AiProposalModel? activeProposal,
    bool hasApprovedProposal = false,
  }) {
    return _conversationEngine.classifyIntent(
      input: input,
      activeProposal: activeProposal,
      hasApprovedProposal: hasApprovedProposal,
    );
  }

  AiCfoProposalLifecycle resolveLifecycle({
    AiProposalModel? activeProposal,
    AiProposalModel? confirmationProposal,
    required AiCfoProposalSessionState sessionState,
    bool isExecuting = false,
  }) {
    final proposal = activeProposal ?? confirmationProposal;
    final proposalId = proposal == null
        ? null
        : _lifecycleResolver.proposalSessionId(proposal);
    final isExecuted = proposalId != null &&
        sessionState.executedProposalIds.contains(proposalId);
    final isFailed = proposalId != null &&
        sessionState.failureReasons.containsKey(proposalId);
    final blockedReason =
        proposalId == null ? null : sessionState.blockedReasons[proposalId];

    return _lifecycleResolver.resolve(
      activeProposal: activeProposal,
      confirmationProposal: confirmationProposal,
      reviewedProposalIds: sessionState.reviewedProposalIds,
      approvedProposalIds: sessionState.approvedProposalIds,
      deferredFollowUps: sessionState.deferredProposalIds.toList(),
      isExecuting: isExecuting,
      lastExecutionSucceeded: isExecuted,
      lastExecutionFailed: isFailed,
      reason: blockedReason,
    );
  }

  Future<AiCfoProposalSessionControllerResult> resolveCommand({
    required String input,
    required String businessId,
    required AiCfoProposalSessionState sessionState,
    AiProposalModel? activeProposal,
    AiProposalModel? confirmationProposal,
  }) async {
    final proposal = activeProposal ?? confirmationProposal;
    final lifecycle = resolveLifecycle(
      activeProposal: activeProposal,
      confirmationProposal: confirmationProposal,
      sessionState: sessionState,
    );
    final hasApprovedProposal =
        lifecycle.state == AiCfoProposalLifecycleState.approved ||
            (proposal != null &&
                sessionState.approvedProposalIds
                    .contains(proposalSessionId(proposal)));
    final intent = classifyIntent(
      input: input,
      activeProposal: proposal,
      hasApprovedProposal: hasApprovedProposal,
    );
    final response = await _conversationEngine.resolve(
      input: input,
      businessId: businessId,
      activeProposal: proposal,
      lifecycle: lifecycle,
      hasApprovedProposal: hasApprovedProposal,
    );
    final command = _commandAdapter.adapt(
      intent: intent,
      lifecycle: lifecycle,
      response: response,
      activeProposal: proposal,
    );

    return AiCfoProposalSessionControllerResult(
      action: _actionFor(command: command, response: response),
      command: command,
      lifecycle: lifecycle,
      sessionState: sessionState,
      response: response,
      proposal: command.proposal ?? response?.proposal ?? proposal,
      reason: command.reason.isNotEmpty
          ? command.reason
          : response?.blockedReason ?? response?.message ?? '',
      requiresScreenAction: command.requiresScreenAction || response != null,
      canDelegateExecution:
          command.type == AiCfoProposalCommandType.executeProposal &&
              command.canMutateLedger,
    );
  }

  AiCfoProposalSessionState reduceEvent({
    required AiCfoProposalSessionState state,
    required AiCfoProposalStateEvent event,
  }) {
    return _stateReducer.reduce(state: state, event: event);
  }

  AiCfoProposalSessionState reduceOutcome({
    required AiCfoProposalSessionState state,
    required AiCfoExecutionOutcome outcome,
  }) {
    final event = _outcomeNormalizer.toStateEventOrNull(outcome);
    if (event == null) return state;
    return reduceEvent(state: state, event: event);
  }

  AiCfoProposalSessionControllerAction _actionFor({
    required AiCfoProposalCommand command,
    required Object? response,
  }) {
    return switch (command.type) {
      AiCfoProposalCommandType.none => response == null
          ? AiCfoProposalSessionControllerAction.none
          : AiCfoProposalSessionControllerAction.appendResponse,
      AiCfoProposalCommandType.showGuardMessage =>
        AiCfoProposalSessionControllerAction.showGuardMessage,
      AiCfoProposalCommandType.reviewProposal =>
        AiCfoProposalSessionControllerAction.reviewProposal,
      AiCfoProposalCommandType.approveProposal =>
        AiCfoProposalSessionControllerAction.approveProposal,
      AiCfoProposalCommandType.deferProposal =>
        AiCfoProposalSessionControllerAction.deferProposal,
      AiCfoProposalCommandType.executeProposal =>
        AiCfoProposalSessionControllerAction.executeProposal,
    };
  }
}
