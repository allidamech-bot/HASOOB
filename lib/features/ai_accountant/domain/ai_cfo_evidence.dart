enum AiCfoEvidenceConfidence {
  high,
  medium,
  low,
}

class AiCfoEvidence {
  final String label;
  final String value;
  final String source;
  final AiCfoEvidenceConfidence confidence;
  final String explanation;

  const AiCfoEvidence({
    required this.label,
    required this.value,
    required this.source,
    required this.confidence,
    required this.explanation,
  });

  bool get isGrounded => source.trim().isNotEmpty;
}
