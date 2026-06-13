import 'dart:math' as math;

import 'ai_evidence_bundle.dart';

enum AiTradeRiskLevel {
  low,
  medium,
  high,
  critical,
}

enum AiTradeRecommendation {
  proceed,
  proceedWithCaution,
  renegotiate,
  reject,
}

class AiShipmentScenarioImpact {
  final String name;
  final double expectedRevenue;
  final double totalLandedCost;
  final double expectedProfit;
  final double marginPercent;
  final AiTradeRiskLevel riskLevel;
  final AiTradeRecommendation recommendation;

  const AiShipmentScenarioImpact({
    required this.name,
    required this.expectedRevenue,
    required this.totalLandedCost,
    required this.expectedProfit,
    required this.marginPercent,
    required this.riskLevel,
    required this.recommendation,
  });
}

class AiShipmentDecisionInput {
  final double purchaseCostPerUnit;
  final double freightCost;
  final double customsCost;
  final double storageCost;
  final double sellingPricePerUnit;
  final double expectedVolume;
  final double currencyRate;
  final List<String> evidence;
  final List<String> assumptions;

  const AiShipmentDecisionInput({
    required this.purchaseCostPerUnit,
    required this.freightCost,
    required this.customsCost,
    required this.storageCost,
    required this.sellingPricePerUnit,
    required this.expectedVolume,
    this.currencyRate = 1,
    this.evidence = const [],
    this.assumptions = const [],
  });

  double get convertedPurchaseCostPerUnit => purchaseCostPerUnit * currencyRate;
  double get logisticsCost => freightCost + customsCost + storageCost;
}

class AiShipmentDecisionResult {
  final double expectedRevenue;
  final double totalLandedCost;
  final double landedCostPerUnit;
  final double expectedProfit;
  final double marginPercent;
  final int breakEvenPointUnits;
  final AiTradeRiskLevel riskLevel;
  final AiTradeRecommendation recommendation;
  final List<String> assumptions;
  final List<String> evidence;
  final AiEvidenceConfidence confidence;
  final List<AiShipmentScenarioImpact> scenarios;

  const AiShipmentDecisionResult({
    required this.expectedRevenue,
    required this.totalLandedCost,
    required this.landedCostPerUnit,
    required this.expectedProfit,
    required this.marginPercent,
    required this.breakEvenPointUnits,
    required this.riskLevel,
    required this.recommendation,
    required this.assumptions,
    required this.evidence,
    required this.confidence,
    required this.scenarios,
  });

  String get riskLabel => riskLevel.name.toUpperCase();

  String get recommendedAction {
    switch (recommendation) {
      case AiTradeRecommendation.proceed:
        return 'proceed';
      case AiTradeRecommendation.proceedWithCaution:
        return 'proceed with caution';
      case AiTradeRecommendation.renegotiate:
        return 'renegotiate';
      case AiTradeRecommendation.reject:
        return 'reject';
    }
  }
}

class AiImportExportCfoAdvisor {
  AiShipmentDecisionResult evaluateShipment(AiShipmentDecisionInput input) {
    final base = _calculate(input);
    final risk = _riskFor(base.marginPercent, base.expectedProfit);
    final recommendation = _recommendationFor(risk, base.marginPercent);

    return AiShipmentDecisionResult(
      expectedRevenue: base.expectedRevenue,
      totalLandedCost: base.totalLandedCost,
      landedCostPerUnit: base.landedCostPerUnit,
      expectedProfit: base.expectedProfit,
      marginPercent: base.marginPercent,
      breakEvenPointUnits: base.breakEvenPointUnits,
      riskLevel: risk,
      recommendation: recommendation,
      assumptions: _assumptionsFor(input),
      evidence: _evidenceFor(input),
      confidence: _confidenceFor(input),
      scenarios: _scenarioImpacts(input),
    );
  }

  _ShipmentMath _calculate(AiShipmentDecisionInput input) {
    final volume = math.max(0, input.expectedVolume);
    final convertedPurchase = input.convertedPurchaseCostPerUnit;
    final totalPurchaseCost = convertedPurchase * volume;
    final totalLandedCost = totalPurchaseCost + input.logisticsCost;
    final landedCostPerUnit = volume <= 0 ? 0.0 : totalLandedCost / volume;
    final expectedRevenue = input.sellingPricePerUnit * volume;
    final expectedProfit = expectedRevenue - totalLandedCost;
    final marginPercent =
        expectedRevenue <= 0 ? 0.0 : expectedProfit / expectedRevenue * 100;
    final breakEvenPointUnits = input.sellingPricePerUnit <= 0
        ? 0
        : (totalLandedCost / input.sellingPricePerUnit).ceil();

    return _ShipmentMath(
      expectedRevenue: _money(expectedRevenue),
      totalLandedCost: _money(totalLandedCost),
      landedCostPerUnit: _money(landedCostPerUnit),
      expectedProfit: _money(expectedProfit),
      marginPercent: _percent(marginPercent),
      breakEvenPointUnits: breakEvenPointUnits,
    );
  }

  List<AiShipmentScenarioImpact> _scenarioImpacts(
    AiShipmentDecisionInput input,
  ) {
    final scenarios = <(String, AiShipmentDecisionInput)>[
      (
        'freight increases 15%',
        AiShipmentDecisionInput(
          purchaseCostPerUnit: input.purchaseCostPerUnit,
          freightCost: input.freightCost * 1.15,
          customsCost: input.customsCost,
          storageCost: input.storageCost,
          sellingPricePerUnit: input.sellingPricePerUnit,
          expectedVolume: input.expectedVolume,
          currencyRate: input.currencyRate,
          evidence: input.evidence,
          assumptions: input.assumptions,
        )
      ),
      (
        'currency cost increases 10%',
        AiShipmentDecisionInput(
          purchaseCostPerUnit: input.purchaseCostPerUnit,
          freightCost: input.freightCost,
          customsCost: input.customsCost,
          storageCost: input.storageCost,
          sellingPricePerUnit: input.sellingPricePerUnit,
          expectedVolume: input.expectedVolume,
          currencyRate: input.currencyRate * 1.10,
          evidence: input.evidence,
          assumptions: input.assumptions,
        )
      ),
      (
        'customs increases 15%',
        AiShipmentDecisionInput(
          purchaseCostPerUnit: input.purchaseCostPerUnit,
          freightCost: input.freightCost,
          customsCost: input.customsCost * 1.15,
          storageCost: input.storageCost,
          sellingPricePerUnit: input.sellingPricePerUnit,
          expectedVolume: input.expectedVolume,
          currencyRate: input.currencyRate,
          evidence: input.evidence,
          assumptions: input.assumptions,
        )
      ),
      (
        'sales volume decreases 20%',
        AiShipmentDecisionInput(
          purchaseCostPerUnit: input.purchaseCostPerUnit,
          freightCost: input.freightCost,
          customsCost: input.customsCost,
          storageCost: input.storageCost,
          sellingPricePerUnit: input.sellingPricePerUnit,
          expectedVolume: input.expectedVolume * 0.80,
          currencyRate: input.currencyRate,
          evidence: input.evidence,
          assumptions: input.assumptions,
        )
      ),
    ];

    return scenarios.map((scenario) {
      final math = _calculate(scenario.$2);
      final risk = _riskFor(math.marginPercent, math.expectedProfit);
      return AiShipmentScenarioImpact(
        name: scenario.$1,
        expectedRevenue: math.expectedRevenue,
        totalLandedCost: math.totalLandedCost,
        expectedProfit: math.expectedProfit,
        marginPercent: math.marginPercent,
        riskLevel: risk,
        recommendation: _recommendationFor(risk, math.marginPercent),
      );
    }).toList();
  }

  AiTradeRiskLevel _riskFor(double marginPercent, double expectedProfit) {
    if (expectedProfit <= 0 || marginPercent < 5) {
      return AiTradeRiskLevel.critical;
    }
    if (marginPercent < 15) return AiTradeRiskLevel.high;
    if (marginPercent < 25) return AiTradeRiskLevel.medium;
    return AiTradeRiskLevel.low;
  }

  AiTradeRecommendation _recommendationFor(
    AiTradeRiskLevel risk,
    double marginPercent,
  ) {
    switch (risk) {
      case AiTradeRiskLevel.low:
        return AiTradeRecommendation.proceed;
      case AiTradeRiskLevel.medium:
        return AiTradeRecommendation.proceedWithCaution;
      case AiTradeRiskLevel.high:
        return AiTradeRecommendation.renegotiate;
      case AiTradeRiskLevel.critical:
        return AiTradeRecommendation.reject;
    }
  }

  AiEvidenceConfidence _confidenceFor(AiShipmentDecisionInput input) {
    final hasCoreInputs = input.purchaseCostPerUnit > 0 &&
        input.sellingPricePerUnit > 0 &&
        input.expectedVolume > 0;
    final hasCostBreakdown = input.freightCost > 0 &&
        input.customsCost > 0 &&
        input.storageCost >= 0;
    if (hasCoreInputs && hasCostBreakdown && input.evidence.length >= 3) {
      return AiEvidenceConfidence.high;
    }
    if (hasCoreInputs && input.evidence.isNotEmpty) {
      return AiEvidenceConfidence.medium;
    }
    return AiEvidenceConfidence.low;
  }

  List<String> _assumptionsFor(AiShipmentDecisionInput input) {
    return [
      ...input.assumptions,
      if (input.currencyRate != 1)
        'Purchase cost converted at currency rate ${input.currencyRate.toStringAsFixed(4)}.',
      if (input.currencyRate == 1)
        'Purchase and selling prices use the same currency.',
      'All freight, customs, and storage costs are treated as shipment-level landed costs.',
      'Break-even point is the units that must sell to cover total landed cost.',
    ];
  }

  List<String> _evidenceFor(AiShipmentDecisionInput input) {
    return [
      ...input.evidence,
      'purchase cost per unit: ${input.purchaseCostPerUnit.toStringAsFixed(2)}',
      'freight cost: ${input.freightCost.toStringAsFixed(2)}',
      'customs cost: ${input.customsCost.toStringAsFixed(2)}',
      'storage cost: ${input.storageCost.toStringAsFixed(2)}',
      'selling price per unit: ${input.sellingPricePerUnit.toStringAsFixed(2)}',
      'expected volume: ${input.expectedVolume.toStringAsFixed(0)}',
    ];
  }

  double _money(double value) => double.parse(value.toStringAsFixed(2));

  double _percent(double value) => double.parse(value.toStringAsFixed(2));
}

class _ShipmentMath {
  final double expectedRevenue;
  final double totalLandedCost;
  final double landedCostPerUnit;
  final double expectedProfit;
  final double marginPercent;
  final int breakEvenPointUnits;

  const _ShipmentMath({
    required this.expectedRevenue,
    required this.totalLandedCost,
    required this.landedCostPerUnit,
    required this.expectedProfit,
    required this.marginPercent,
    required this.breakEvenPointUnits,
  });
}
