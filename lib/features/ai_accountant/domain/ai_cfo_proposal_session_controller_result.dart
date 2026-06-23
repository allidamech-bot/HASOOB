import '../data/models/ai_proposal_model.dart';
import 'ai_cfo_conversation_response.dart';
import 'ai_cfo_proposal_command.dart';
import 'ai_cfo_proposal_lifecycle.dart';
import 'ai_cfo_proposal_session_state.dart';

enum AiCfoProposalSessionControllerAction {
  none,
  appendResponse,
  showGuardMessage,
  reviewProposal,
  approveProposal,
  deferProposal,
  executeProposal,
  updateSessionState,
}

class AiCfoProposalSessionControllerResult {
  final AiCfoProposalSessionControllerAction action;
  final AiCfoProposalCommand command;
  final AiCfoProposalLifecycle lifecycle;
  final AiCfoProposalSessionState sessionState;
  final AiCfoConversationResponse? response;
  final AiProposalModel? proposal;
  final String reason;
  final bool requiresScreenAction;
  final bool canDelegateExecution;
  final bool isSessionOnly;

  const AiCfoProposalSessionControllerResult({
    required this.action,
    required this.command,
    required this.lifecycle,
    required this.sessionState,
    this.response,
    this.proposal,
    this.reason = '',
    this.requiresScreenAction = false,
    this.canDelegateExecution = false,
    this.isSessionOnly = true,
  });

  bool get isNoOp => action == AiCfoProposalSessionControllerAction.none;

  bool get isBlocked =>
      action == AiCfoProposalSessionControllerAction.showGuardMessage ||
      command.isBlocked ||
      response?.isBlocked == true;
}
