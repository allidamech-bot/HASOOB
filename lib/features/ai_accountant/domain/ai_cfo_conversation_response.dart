import '../data/models/ai_proposal_model.dart';
import 'ai_cfo_conversation_intent.dart';
import 'ai_cfo_evidence.dart';

enum AiCfoResponseType {
  answer,
  proposal,
  clarificationNeeded,
  blocked,
  executionResult,
  followUp,
  unsupported,
}

class AiCfoConversationResponse {
  final AiCfoResponseType type;
  final AiCfoConversationIntent intent;
  final String title;
  final String message;
  final List<AiCfoEvidence> evidence;
  final List<String> risks;
  final AiProposalModel? proposal;
  final bool requiresApproval;
  final bool isBlocked;
  final String? blockedReason;
  final bool sessionOnly;
  final bool canExecute;

  const AiCfoConversationResponse({
    required this.type,
    required this.intent,
    required this.title,
    required this.message,
    this.evidence = const [],
    this.risks = const [],
    this.proposal,
    this.requiresApproval = false,
    this.isBlocked = false,
    this.blockedReason,
    this.sessionOnly = true,
    this.canExecute = false,
  });

  bool get hasGroundedEvidence =>
      evidence.isNotEmpty && evidence.every((item) => item.isGrounded);
}
