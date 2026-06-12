import 'ai_tool_planner.dart';

enum AiEvidenceConfidence {
  high,
  medium,
  low,
}

class AiExecutedToolEvidence {
  final String toolName;
  final bool success;
  final String reason;
  final dynamic data;
  final String? error;

  const AiExecutedToolEvidence({
    required this.toolName,
    required this.success,
    required this.reason,
    this.data,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'toolName': toolName,
        'success': success,
        'reason': reason,
        'data': data,
        'error': error,
      };
}

class AiEvidenceBundle {
  final List<AiExecutedToolEvidence> executedTools;
  final List<dynamic> records;
  final Map<String, dynamic> summaries;
  final List<String> missingEvidence;
  final AiEvidenceConfidence confidenceLevel;

  const AiEvidenceBundle({
    this.executedTools = const [],
    this.records = const [],
    this.summaries = const {},
    this.missingEvidence = const [],
    this.confidenceLevel = AiEvidenceConfidence.low,
  });

  factory AiEvidenceBundle.fromToolResults({
    required AiToolPlan plan,
    required List<AiExecutedToolEvidence> tools,
  }) {
    final records = <dynamic>[];
    final summaries = <String, dynamic>{};
    final missing = <String>[...plan.missingInputs];

    for (final tool in tools) {
      if (!tool.success) {
        missing.add('${tool.toolName}: ${tool.error ?? 'no data'}');
        continue;
      }
      final data = tool.data;
      if (data is Map) {
        summaries[tool.toolName] = Map<String, dynamic>.from(data);
        final toolRecords = data['records'];
        if (toolRecords is List) records.addAll(toolRecords);
      } else if (data != null) {
        summaries[tool.toolName] = data;
      }
    }

    return AiEvidenceBundle(
      executedTools: tools,
      records: records,
      summaries: summaries,
      missingEvidence: missing.toSet().toList(),
      confidenceLevel:
          _confidenceFor(plan: plan, tools: tools, records: records),
    );
  }

  factory AiEvidenceBundle.empty({
    required AiToolPlan plan,
    List<String> missingEvidence = const [],
  }) {
    return AiEvidenceBundle(
      missingEvidence: <String>{
        ...plan.missingInputs,
        ...missingEvidence,
      }.toList(),
      confidenceLevel: AiEvidenceConfidence.low,
    );
  }

  bool get hasToolData => executedTools.any((tool) => tool.success);

  Map<String, dynamic> toJson() => {
        'executedTools': executedTools.map((tool) => tool.toJson()).toList(),
        'records': records,
        'summaries': summaries,
        'missingEvidence': missingEvidence,
        'confidenceLevel': confidenceLevel.name,
      };

  static AiEvidenceConfidence _confidenceFor({
    required AiToolPlan plan,
    required List<AiExecutedToolEvidence> tools,
    required List<dynamic> records,
  }) {
    if (tools.isEmpty) return AiEvidenceConfidence.low;
    final successfulRequired = plan.steps.where((step) => step.required).every(
        (step) => tools
            .any((tool) => tool.toolName == step.toolName && tool.success));
    final anySuccess = tools.any((tool) => tool.success);
    if (successfulRequired &&
        (records.isNotEmpty ||
            plan.intent == AiAccountantIntent.financialOverview ||
            plan.intent == AiAccountantIntent.cashFlowAnalysis)) {
      return AiEvidenceConfidence.high;
    }
    if (anySuccess) return AiEvidenceConfidence.medium;
    return AiEvidenceConfidence.low;
  }
}
