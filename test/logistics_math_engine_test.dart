import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/utils/logistics_math_engine.dart';

void main() {
  group('LogisticsMathEngine', () {
    test('calculates precise landed cost with proportional allocation', () {
      final landedCost = LogisticsMathEngine.calculatePreciseLandedCost(
        itemBasePrice: 45.0,
        itemVolumeCbm: 0.09,
        totalShippingCost: 1200.0,
        totalCustomsDuties: 300.0,
        totalBatchVolumeCbm: 33.2,
      );

      expect(landedCost, closeTo(45.0 + ((1500.0 * 0.09) / 33.2), 0.0001));
    });

    test('calculates suggested selling price with strict margin guardrails', () {
      final suggestedPrice = LogisticsMathEngine.calculateSuggestedSellingPrice(
        landedCostPerUnit: 51.37,
        targetMarginPercentage: 25.0,
      );

      expect(suggestedPrice, closeTo(68.4933333333, 0.0001));
    });

    test('returns base price when batch volume is invalid', () {
      final landedCost = LogisticsMathEngine.calculatePreciseLandedCost(
        itemBasePrice: 40.0,
        itemVolumeCbm: 0.1,
        totalShippingCost: 100.0,
        totalCustomsDuties: 10.0,
        totalBatchVolumeCbm: 0.0,
      );

      expect(landedCost, 40.0);
    });
  });
}
