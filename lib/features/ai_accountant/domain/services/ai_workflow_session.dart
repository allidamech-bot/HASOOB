import 'ai_data_collection_state.dart';

class AiWorkflowSession {
  final String workflowId;
  final AiWorkflowType workflowType;
  final int currentStep;
  final Map<String, dynamic> collectedData;
  final List<String> missingFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiWorkflowSession({
    required this.workflowId,
    required this.workflowType,
    required this.currentStep,
    required this.collectedData,
    required this.missingFields,
    required this.createdAt,
    required this.updatedAt,
  });

  AiWorkflowSession copyWith({
    int? currentStep,
    Map<String, dynamic>? collectedData,
    List<String>? missingFields,
    DateTime? updatedAt,
  }) {
    return AiWorkflowSession(
      workflowId: workflowId,
      workflowType: workflowType,
      currentStep: currentStep ?? this.currentStep,
      collectedData: collectedData ?? this.collectedData,
      missingFields: missingFields ?? this.missingFields,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get totalSteps => collectedData.length + missingFields.length;
  bool get isComplete => missingFields.isEmpty;
  String? get waitingField =>
      missingFields.isEmpty ? null : missingFields.first;
}

class AiWorkflowTurnResult {
  final AiWorkflowSession? session;
  final String responseText;
  final bool isComplete;
  final bool isCancelled;
  final String? proposalDraftText;
  final List<String> suggestedReplies;

  const AiWorkflowTurnResult({
    required this.session,
    required this.responseText,
    this.isComplete = false,
    this.isCancelled = false,
    this.proposalDraftText,
    this.suggestedReplies = const [],
  });
}
