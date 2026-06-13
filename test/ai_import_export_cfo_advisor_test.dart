import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_decision_questionnaire.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_evidence_bundle.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_financial_decision_engine.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_import_export_cfo_advisor.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/ai_tool_planner.dart';

void main() {
  group('AiImportExportCfoAdvisor', () {
    test('profitable shipment proceeds with landed cost and break-even', () {
      final result = AiImportExportCfoAdvisor().evaluateShipment(
        const AiShipmentDecisionInput(
          purchaseCostPerUnit: 30,
          freightCost: 600,
          customsCost: 300,
          storageCost: 100,
          sellingPricePerUnit: 50,
          expectedVolume: 200,
          evidence: [
            'supplier quote',
            'freight quote',
            'customer price list',
          ],
        ),
      );

      expect(result.expectedRevenue, 10000);
      expect(result.totalLandedCost, 7000);
      expect(result.landedCostPerUnit, 35);
      expect(result.expectedProfit, 3000);
      expect(result.marginPercent, 30);
      expect(result.breakEvenPointUnits, 140);
      expect(result.riskLevel, AiTradeRiskLevel.low);
      expect(result.recommendation, AiTradeRecommendation.proceed);
      expect(result.confidence, AiEvidenceConfidence.high);
      expect(
          result.scenarios.map((scenario) => scenario.name),
          containsAll([
            'freight increases 15%',
            'currency cost increases 10%',
            'customs increases 15%',
            'sales volume decreases 20%',
          ]));
    });

    test('risky shipment recommends renegotiation', () {
      final result = AiImportExportCfoAdvisor().evaluateShipment(
        const AiShipmentDecisionInput(
          purchaseCostPerUnit: 36,
          freightCost: 600,
          customsCost: 300,
          storageCost: 100,
          sellingPricePerUnit: 50,
          expectedVolume: 100,
          evidence: [
            'supplier quote',
            'freight quote',
            'expected selling price',
          ],
        ),
      );

      expect(result.expectedRevenue, 5000);
      expect(result.totalLandedCost, 4600);
      expect(result.expectedProfit, 400);
      expect(result.marginPercent, 8);
      expect(result.riskLevel, AiTradeRiskLevel.high);
      expect(result.recommendation, AiTradeRecommendation.renegotiate);
      expect(result.recommendedAction, 'renegotiate');
    });

    test('unprofitable shipment is rejected', () {
      final result = AiImportExportCfoAdvisor().evaluateShipment(
        const AiShipmentDecisionInput(
          purchaseCostPerUnit: 45,
          freightCost: 500,
          customsCost: 200,
          storageCost: 100,
          sellingPricePerUnit: 50,
          expectedVolume: 100,
          evidence: [
            'supplier quote',
            'freight quote',
            'expected selling price',
          ],
        ),
      );

      expect(result.expectedRevenue, 5000);
      expect(result.totalLandedCost, 5300);
      expect(result.expectedProfit, -300);
      expect(result.marginPercent, -6);
      expect(result.riskLevel, AiTradeRiskLevel.critical);
      expect(result.recommendation, AiTradeRecommendation.reject);
      expect(result.recommendedAction, 'reject');
    });

    test('decision engine exposes import shipment analysis outputs', () {
      final result = AiFinancialDecisionEngine().evaluate(
        decisionType: AiFinancialDecisionType.importShipment,
        inputs: const {
          AiDecisionInputField.quantity: 100,
          AiDecisionInputField.unitCost: 30,
          AiDecisionInputField.importCosts: 1000,
          AiDecisionInputField.expectedSellingPrice: 50,
          AiDecisionInputField.demandEvidence: 'confirmed distributor order',
        },
        evidence: AiEvidenceBundle.empty(plan: _importPlan),
        questionnaire: AiDecisionQuestionnaire(),
      );

      expect(result.recommendation, 'proceed with caution');
      expect(result.shipmentDecision, isNotNull);
      expect(result.shipmentDecision!.expectedRevenue, 5000);
      expect(result.shipmentDecision!.totalLandedCost, 4000);
      expect(result.shipmentDecision!.expectedProfit, 1000);
      expect(result.shipmentDecision!.marginPercent, 20);
      expect(result.shipmentDecision!.breakEvenPointUnits, 80);
      expect(
          result.rationaleSummary, contains('Shipment profitability analysis'));
      expect(result.rationaleSummary, contains('total landed cost 4000.00'));
      expect(result.scenarios, hasLength(4));
    });
  });
}

const _importPlan = AiToolPlan(
  intent: AiAccountantIntent.exportDecision,
  requiresTools: false,
  steps: [],
  missingInputs: [],
  safetyLevel: AiToolSafetyLevel.advisoryOnly,
);
