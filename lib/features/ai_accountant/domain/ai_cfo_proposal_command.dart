import '../data/models/ai_proposal_model.dart';
import 'ai_cfo_conversation_response.dart';

enum AiCfoProposalCommandType {
  none,
  showGuardMessage,
  reviewProposal,
  approveProposal,
  deferProposal,
  executeProposal,
}

class AiCfoProposalCommand {
  final AiCfoProposalCommandType type;
  final AiProposalModel? proposal;
  final AiCfoConversationResponse? response;
  final String reason;
  final bool requiresScreenAction;
  final bool canMutateLedger;
  final bool isSessionOnly;

  const AiCfoProposalCommand({
    required this.type,
    this.proposal,
    this.response,
    this.reason = '',
    this.requiresScreenAction = false,
    this.canMutateLedger = false,
    this.isSessionOnly = true,
  });

  bool get isNoOp => type == AiCfoProposalCommandType.none;
  bool get isBlocked =>
      type == AiCfoProposalCommandType.showGuardMessage ||
      response?.isBlocked == true;
}
