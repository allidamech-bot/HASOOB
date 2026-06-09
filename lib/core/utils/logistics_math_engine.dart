import 'dart:math' as math;

/// Enterprise-grade arithmetic utilities for landed-cost and pricing simulations.
class LogisticsMathEngine {
  static const double _standardTwentyFootContainerVolumeCbm = 33.2;
  static const double _standardBoxVolumeCbm = 0.045;
  static const int _financialRoundingPrecision = 4;

  /// Calculates the precise landed cost per unit by allocating freight and duties
  /// proportionally to the item's volumetric share of the shipment.
  static double calculatePreciseLandedCost({
    required double itemBasePrice,
    required double itemVolumeCbm,
    required double totalShippingCost,
    required double totalCustomsDuties,
    required double totalBatchVolumeCbm,
  }) {
    if (totalBatchVolumeCbm <= 0 || itemVolumeCbm <= 0) {
      return _roundCurrency(itemBasePrice);
    }

    final volumetricShare = itemVolumeCbm / totalBatchVolumeCbm;
    final allocatedLogisticsCost = (totalShippingCost + totalCustomsDuties) * volumetricShare;
    final landedCost = itemBasePrice + allocatedLogisticsCost;

    return _roundCurrency(landedCost);
  }

  /// Calculates the suggested selling price for a target margin percentage.
  static double calculateSuggestedSellingPrice({
    required double landedCostPerUnit,
    required double targetMarginPercentage,
  }) {
    if (landedCostPerUnit <= 0) return 0.0;

    final normalizedMargin = targetMarginPercentage / 100.0;
    if (normalizedMargin >= 1.0) return _roundCurrency(landedCostPerUnit);

    final suggestedPrice = landedCostPerUnit / (1.0 - normalizedMargin);
    return _roundCurrency(suggestedPrice);
  }

  /// Estimates how many standard boxes can fit in a 20-foot container.
  static int estimateTotalBoxes({
    double totalBatchVolumeCbm = _standardTwentyFootContainerVolumeCbm,
    double standardBoxVolumeCbm = _standardBoxVolumeCbm,
  }) {
    if (totalBatchVolumeCbm <= 0 || standardBoxVolumeCbm <= 0) {
      return 0;
    }

    final estimatedBoxes = totalBatchVolumeCbm / standardBoxVolumeCbm;
    return math.max(1, estimatedBoxes.round());
  }

  static double _roundCurrency(double value) {
    return double.parse(value.toStringAsFixed(_financialRoundingPrecision));
  }
}
