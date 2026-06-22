class AiCfoProposalSessionState {
  final Set<String> reviewedProposalIds;
  final Set<String> deferredProposalIds;
  final Set<String> approvedProposalIds;
  final Set<String> executedProposalIds;
  final Map<String, String> blockedReasons;
  final Map<String, String> failureReasons;

  const AiCfoProposalSessionState({
    this.reviewedProposalIds = const {},
    this.deferredProposalIds = const {},
    this.approvedProposalIds = const {},
    this.executedProposalIds = const {},
    this.blockedReasons = const {},
    this.failureReasons = const {},
  });

  factory AiCfoProposalSessionState.empty() {
    return const AiCfoProposalSessionState();
  }

  bool isReviewed(String proposalId) =>
      reviewedProposalIds.contains(proposalId);
  bool isDeferred(String proposalId) =>
      deferredProposalIds.contains(proposalId);
  bool isApproved(String proposalId) =>
      approvedProposalIds.contains(proposalId);
  bool isExecuted(String proposalId) =>
      executedProposalIds.contains(proposalId);
  bool isBlocked(String proposalId) => blockedReasons.containsKey(proposalId);
  bool isFailed(String proposalId) => failureReasons.containsKey(proposalId);

  bool get isSessionOnly => true;

  AiCfoProposalSessionState copyWith({
    Set<String>? reviewedProposalIds,
    Set<String>? deferredProposalIds,
    Set<String>? approvedProposalIds,
    Set<String>? executedProposalIds,
    Map<String, String>? blockedReasons,
    Map<String, String>? failureReasons,
  }) {
    return AiCfoProposalSessionState(
      reviewedProposalIds:
          Set.unmodifiable(reviewedProposalIds ?? this.reviewedProposalIds),
      deferredProposalIds:
          Set.unmodifiable(deferredProposalIds ?? this.deferredProposalIds),
      approvedProposalIds:
          Set.unmodifiable(approvedProposalIds ?? this.approvedProposalIds),
      executedProposalIds:
          Set.unmodifiable(executedProposalIds ?? this.executedProposalIds),
      blockedReasons: Map.unmodifiable(blockedReasons ?? this.blockedReasons),
      failureReasons: Map.unmodifiable(failureReasons ?? this.failureReasons),
    );
  }
}
