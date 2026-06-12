import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_snapshot.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_insight_generator.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_risk_detector.dart';

void main() {
  group('AI insight and risk generation', () {
    test('generates high and medium risks from snapshot', () {
      const snapshot = AiFinancialSnapshot(
        pendingInvoices: 500,
        overdueInvoices: 3,
        inventoryHealth: 'needs_attention',
        lowStockProducts: 2,
        customerRisk: 'open_balances',
        confidence: AiEvidenceConfidence.high,
      );

      final risks = AiRiskDetector().detect(snapshot);

      expect(
          risks.map((risk) => risk.level), contains(AiFinancialRiskLevel.high));
      expect(risks.map((risk) => risk.title), contains('Overdue invoices'));
      expect(risks.map((risk) => risk.title), contains('Low stock'));
    });

    test('generates recommendations from risks', () {
      const snapshot = AiFinancialSnapshot(
        overdueInvoices: 3,
        lowStockProducts: 2,
        confidence: AiEvidenceConfidence.high,
      );
      final risks = AiRiskDetector().detect(snapshot);

      final recommendations = AiInsightGenerator().generateRecommendations(
        snapshot: snapshot,
        risks: risks,
      );

      expect(
        recommendations.map((item) => item.title),
        contains('Follow up overdue customers'),
      );
      expect(
        recommendations.map((item) => item.title),
        contains('Review replenishment'),
      );
    });

    test('generates missing evidence risk and recommendation', () {
      const snapshot = AiFinancialSnapshot(
        confidence: AiEvidenceConfidence.low,
        missingData: ['invoices', 'customers'],
      );

      final risks = AiRiskDetector().detect(snapshot);
      final recommendations = AiInsightGenerator().generateRecommendations(
        snapshot: snapshot,
        risks: risks,
      );

      expect(risks.map((risk) => risk.title), contains('Missing evidence'));
      expect(
        recommendations.map((item) => item.title),
        contains('Complete missing evidence'),
      );
    });
  });
}
