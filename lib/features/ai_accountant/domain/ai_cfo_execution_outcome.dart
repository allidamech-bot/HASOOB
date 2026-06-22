import '../data/models/ai_proposal_model.dart';

enum AiCfoExecutionOutcomeType {
  none,
  blocked,
  skipped,
  started,
  succeeded,
  failed,
}

class AiCfoExecutionOutcome {
  final AiCfoExecutionOutcomeType type;
  final AiProposalModel? proposal;
  final String? proposalSessionId;
  final String message;
  final String? reason;
  final bool completedExternally;
  final bool mutatedLedger;
  final bool isSessionOnly;

  const AiCfoExecutionOutcome({
    required this.type,
    this.proposal,
    this.proposalSessionId,
    this.message = '',
    this.reason,
    this.completedExternally = false,
    this.mutatedLedger = false,
    this.isSessionOnly = true,
  });

  bool get isTerminal =>
      type == AiCfoExecutionOutcomeType.blocked ||
      type == AiCfoExecutionOutcomeType.skipped ||
      type == AiCfoExecutionOutcomeType.succeeded ||
      type == AiCfoExecutionOutcomeType.failed;

  bool get isSuccess => type == AiCfoExecutionOutcomeType.succeeded;
  bool get isFailure => type == AiCfoExecutionOutcomeType.failed;
  bool get isBlocked => type == AiCfoExecutionOutcomeType.blocked;
}
