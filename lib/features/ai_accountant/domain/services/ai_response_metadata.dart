import 'ai_evidence_bundle.dart';

class AiResponseMetadata {
  final AiEvidenceConfidence confidenceLevel;
  final List<String> executedTools;
  final List<String> missingEvidence;
  final int evidenceCount;
  final DateTime generatedAt;

  const AiResponseMetadata({
    required this.confidenceLevel,
    required this.executedTools,
    required this.missingEvidence,
    required this.evidenceCount,
    required this.generatedAt,
  });

  factory AiResponseMetadata.fromEvidence(
    AiEvidenceBundle evidence, {
    DateTime? generatedAt,
  }) {
    return AiResponseMetadata(
      confidenceLevel: evidence.confidenceLevel,
      executedTools: evidence.executedTools
          .where((tool) => tool.success)
          .map((tool) => tool.toolName)
          .toList(),
      missingEvidence: evidence.missingEvidence,
      evidenceCount: evidence.records.length,
      generatedAt: generatedAt ?? DateTime.now(),
    );
  }

  factory AiResponseMetadata.low({
    List<String> missingEvidence = const [],
    DateTime? generatedAt,
  }) {
    return AiResponseMetadata(
      confidenceLevel: AiEvidenceConfidence.low,
      executedTools: const [],
      missingEvidence: missingEvidence,
      evidenceCount: 0,
      generatedAt: generatedAt ?? DateTime.now(),
    );
  }

  String get confidenceLabel => confidenceLevel.name.toUpperCase();

  List<String> get executedToolLabels =>
      executedTools.map(toolDisplayName).toList();

  static String toolDisplayName(String toolName) {
    switch (toolName) {
      case 'getFinancialSummary':
        return 'Financial Summary';
      case 'getProducts':
        return 'Products';
      case 'getCustomers':
        return 'Customers';
      case 'getInvoices':
        return 'Invoices';
      case 'getIncome':
        return 'Income';
      case 'getExpenses':
        return 'Expenses';
      default:
        return toolName;
    }
  }
}
