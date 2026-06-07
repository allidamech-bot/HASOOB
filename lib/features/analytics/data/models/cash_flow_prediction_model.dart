class CashFlowPredictionModel {
  final DateTime targetDate;
  final double expectedInflow;
  final double expectedOutflow;
  final double netLiquidityPosition;
  final double riskProbability; // 0.0 to 1.0
  final List<String> riskAlerts;

  CashFlowPredictionModel({
    required this.targetDate,
    required this.expectedInflow,
    required this.expectedOutflow,
    required this.netLiquidityPosition,
    required this.riskProbability,
    required this.riskAlerts,
  });

  factory CashFlowPredictionModel.fromMap(Map<String, dynamic> map) {
    return CashFlowPredictionModel(
      targetDate: DateTime.parse(map['targetDate']),
      expectedInflow: (map['expectedInflow'] ?? 0.0).toDouble(),
      expectedOutflow: (map['expectedOutflow'] ?? 0.0).toDouble(),
      netLiquidityPosition: (map['netLiquidityPosition'] ?? 0.0).toDouble(),
      riskProbability: (map['riskProbability'] ?? 0.0).toDouble(),
      riskAlerts: List<String>.from(map['riskAlerts'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetDate': targetDate.toIso8601String(),
      'expectedInflow': expectedInflow,
      'expectedOutflow': expectedOutflow,
      'netLiquidityPosition': netLiquidityPosition,
      'riskProbability': riskProbability,
      'riskAlerts': riskAlerts,
    };
  }
}
