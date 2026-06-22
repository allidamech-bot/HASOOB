import 'ai_cfo_conversation_response.dart';
import 'ai_cfo_evidence.dart';

enum AiCfoProposalDecision {
  review,
  approve,
  defer,
  execute,
}

class AiCfoProposalDecisionResult {
  final AiCfoProposalDecision decision;
  final bool allowed;
  final String reason;
  final AiCfoResponseType responseType;
  final AiCfoEvidenceConfidence confidence;

  const AiCfoProposalDecisionResult({
    required this.decision,
    required this.allowed,
    required this.reason,
    required this.responseType,
    required this.confidence,
  });

  bool get denied => !allowed;
  bool get isSessionOnly => true;
}
