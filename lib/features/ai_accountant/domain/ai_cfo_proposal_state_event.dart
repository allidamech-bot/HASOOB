import '../data/models/ai_proposal_model.dart';

enum AiCfoProposalStateEventType {
  reviewed,
  approved,
  deferred,
  executionStarted,
  executed,
  failed,
  blocked,
  cleared,
}

class AiCfoProposalStateEvent {
  final AiCfoProposalStateEventType type;
  final AiProposalModel? proposal;
  final String? proposalSessionId;
  final String reason;
  final DateTime? occurredAt;
  final bool isSessionOnly;
  final bool mutatesLedger;
  final bool completedExternally;

  const AiCfoProposalStateEvent({
    required this.type,
    this.proposal,
    this.proposalSessionId,
    this.reason = '',
    this.occurredAt,
    this.isSessionOnly = true,
    this.mutatesLedger = false,
    this.completedExternally = false,
  });
}
