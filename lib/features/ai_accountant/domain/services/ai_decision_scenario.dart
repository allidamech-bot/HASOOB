enum AiDecisionScenarioRisk {
  low,
  medium,
  high,
}

class AiDecisionScenario {
  final String title;
  final double? estimatedRevenue;
  final double? estimatedCost;
  final double? margin;
  final String cashImpact;
  final String inventoryImpact;
  final AiDecisionScenarioRisk risk;

  const AiDecisionScenario({
    required this.title,
    this.estimatedRevenue,
    this.estimatedCost,
    this.margin,
    required this.cashImpact,
    required this.inventoryImpact,
    required this.risk,
  });

  String get riskLabel => risk.name.toUpperCase();
}
