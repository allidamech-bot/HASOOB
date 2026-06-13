import 'ai_decision_questionnaire.dart';
import 'ai_decision_scenario.dart';
import 'ai_evidence_bundle.dart';
import 'ai_import_export_cfo_advisor.dart';

enum AiFinancialDecisionType {
  inventoryPurchase,
  reorderInventory,
  importShipment,
  pricingChange,
  customerCreditSale,
  dealProfitability,
  stockIncrease,
  unknown,
}

enum AiDecisionRiskLevel {
  low,
  medium,
  high,
}

class AiFinancialDecisionResult {
  final AiFinancialDecisionType decisionType;
  final String recommendation;
  final AiEvidenceConfidence confidence;
  final AiDecisionRiskLevel riskLevel;
  final List<String> missingInputs;
  final String? nextQuestion;
  final String rationaleSummary;
  final List<AiDecisionScenario> scenarios;
  final AiShipmentDecisionResult? shipmentDecision;

  const AiFinancialDecisionResult({
    required this.decisionType,
    required this.recommendation,
    required this.confidence,
    required this.riskLevel,
    required this.missingInputs,
    required this.nextQuestion,
    required this.rationaleSummary,
    this.scenarios = const [],
    this.shipmentDecision,
  });

  bool get needsMoreInformation => nextQuestion != null;
}

class AiFinancialDecisionEngine {
  AiFinancialDecisionType detectDecisionType(String userText) {
    final normalized = userText.toLowerCase().trim();
    if (_containsAny(normalized, [
      'import',
      'shipment',
      'shipping',
      'customs',
      'ط§ط³طھظٹط±ط§ط¯',
      'ط´ط­ظ†ط©',
    ])) {
      return AiFinancialDecisionType.importShipment;
    }
    if (_containsAny(normalized, [
      'reorder',
      'order more',
      'buy more',
      'buy 500',
      'buy inventory',
      'purchase inventory',
      'ط£ط´طھط±ظٹ',
      'ط§ط´طھط±ظٹ',
    ])) {
      return AiFinancialDecisionType.inventoryPurchase;
    }
    if (_containsAny(normalized, [
      'increase stock',
      'more stock',
      'raise stock',
    ])) {
      return AiFinancialDecisionType.stockIncrease;
    }
    if (_containsAny(normalized, [
      'lower price',
      'increase price',
      'discount',
      'change price',
      'ط®ظپط¶ ط§ظ„ط³ط¹ط±',
    ])) {
      return AiFinancialDecisionType.pricingChange;
    }
    if (_containsAny(normalized, [
      'customer safe',
      'sell on credit',
      'credit sale',
      'safe to sell',
      'ط¢ط¬ظ„',
    ])) {
      return AiFinancialDecisionType.customerCreditSale;
    }
    if (_containsAny(normalized, [
      'deal profitable',
      'profitable deal',
      'is this deal profitable',
      'margin on this deal',
    ])) {
      return AiFinancialDecisionType.dealProfitability;
    }
    if (_containsAny(normalized, ['should i', 'do you recommend'])) {
      return AiFinancialDecisionType.unknown;
    }
    return AiFinancialDecisionType.unknown;
  }

  bool isDecisionRequest(String userText) {
    final normalized = userText.toLowerCase().trim();
    if (_containsAny(normalized, [
      'what should i do',
      'what should we do',
      'what do i do',
      'what do we do',
    ])) {
      return false;
    }
    return _containsAny(normalized, [
      'should i',
      'do you recommend',
      'is it safe',
      'is this deal',
      'buy more',
      'reorder',
      'lower price',
      'increase stock',
      'import this',
      'sell on credit',
      'طھظ†طµط­',
      'ظ‡ظ„ ط£ط´طھط±ظٹ',
    ]);
  }

  List<AiDecisionInputField> requiredInputsFor(
    AiFinancialDecisionType decisionType,
  ) {
    switch (decisionType) {
      case AiFinancialDecisionType.inventoryPurchase:
      case AiFinancialDecisionType.reorderInventory:
      case AiFinancialDecisionType.stockIncrease:
        return const [
          AiDecisionInputField.quantity,
          AiDecisionInputField.unitCost,
          AiDecisionInputField.expectedSellingPrice,
          AiDecisionInputField.demandEvidence,
        ];
      case AiFinancialDecisionType.importShipment:
        return const [
          AiDecisionInputField.quantity,
          AiDecisionInputField.unitCost,
          AiDecisionInputField.importCosts,
          AiDecisionInputField.expectedSellingPrice,
          AiDecisionInputField.demandEvidence,
        ];
      case AiFinancialDecisionType.pricingChange:
        return const [
          AiDecisionInputField.unitCost,
          AiDecisionInputField.currentPrice,
          AiDecisionInputField.proposedPrice,
          AiDecisionInputField.demandEvidence,
        ];
      case AiFinancialDecisionType.customerCreditSale:
        return const [
          AiDecisionInputField.customerPaymentHistory,
          AiDecisionInputField.paymentTerms,
        ];
      case AiFinancialDecisionType.dealProfitability:
        return const [
          AiDecisionInputField.quantity,
          AiDecisionInputField.unitCost,
          AiDecisionInputField.expectedSellingPrice,
        ];
      case AiFinancialDecisionType.unknown:
        return const [AiDecisionInputField.quantity];
    }
  }

  AiFinancialDecisionResult evaluate({
    required AiFinancialDecisionType decisionType,
    required Map<AiDecisionInputField, dynamic> inputs,
    required AiEvidenceBundle evidence,
    required AiDecisionQuestionnaire questionnaire,
  }) {
    final requiredInputs = requiredInputsFor(decisionType);
    final missingFields = requiredInputs
        .where((field) => !inputs.containsKey(field))
        .toList(growable: false);
    final nextMissing = missingFields.isEmpty ? null : missingFields.first;
    if (nextMissing != null) {
      return AiFinancialDecisionResult(
        decisionType: decisionType,
        recommendation: 'Do not decide yet.',
        confidence: AiEvidenceConfidence.low,
        riskLevel: AiDecisionRiskLevel.high,
        missingInputs: missingFields.map(_fieldLabel).toList(),
        nextQuestion: questionnaire.questionFor(nextMissing),
        rationaleSummary:
            'This decision needs confirmed inputs before I can protect margin, cash, and inventory exposure.',
      );
    }

    if (decisionType == AiFinancialDecisionType.importShipment) {
      final shipmentDecision = AiImportExportCfoAdvisor().evaluateShipment(
        _shipmentInputFromDecision(inputs),
      );
      return AiFinancialDecisionResult(
        decisionType: decisionType,
        recommendation: shipmentDecision.recommendedAction,
        confidence: _combinedConfidence(
          evidence.confidenceLevel,
          shipmentDecision.confidence,
        ),
        riskLevel: _decisionRiskFromTrade(shipmentDecision.riskLevel),
        missingInputs: const [],
        nextQuestion: null,
        rationaleSummary: _shipmentRationale(shipmentDecision),
        scenarios: _shipmentScenarios(shipmentDecision),
        shipmentDecision: shipmentDecision,
      );
    }

    final scenarios = compareScenarios(
      decisionType: decisionType,
      inputs: inputs,
    );
    final margin = _margin(inputs);
    final risk = _riskFor(decisionType: decisionType, inputs: inputs);
    final recommendation = _recommendationFor(
      decisionType: decisionType,
      margin: margin,
      risk: risk,
    );

    return AiFinancialDecisionResult(
      decisionType: decisionType,
      recommendation: recommendation,
      confidence: evidence.hasToolData
          ? evidence.confidenceLevel
          : AiEvidenceConfidence.medium,
      riskLevel: risk,
      missingInputs: const [],
      nextQuestion: null,
      rationaleSummary: _rationaleFor(
        decisionType: decisionType,
        margin: margin,
        risk: risk,
      ),
      scenarios: scenarios,
    );
  }

  List<AiDecisionScenario> compareScenarios({
    required AiFinancialDecisionType decisionType,
    required Map<AiDecisionInputField, dynamic> inputs,
  }) {
    final quantity = _number(inputs[AiDecisionInputField.quantity]);
    final unitCost = _number(inputs[AiDecisionInputField.unitCost]);
    final price = _number(inputs[AiDecisionInputField.expectedSellingPrice]) ??
        _number(inputs[AiDecisionInputField.proposedPrice]) ??
        _number(inputs[AiDecisionInputField.currentPrice]);

    if (quantity == null || unitCost == null || price == null) {
      return const [];
    }

    final quantities = <double>{
      if (quantity > 100) 100,
      quantity,
      if (quantity < 300) 300,
    }.toList()
      ..sort();

    return quantities.map((qty) {
      final revenue = qty * price;
      final importCosts = decisionType == AiFinancialDecisionType.importShipment
          ? (_number(inputs[AiDecisionInputField.importCosts]) ?? 0)
          : 0;
      final allocatedImportCost =
          quantity == 0 ? 0 : importCosts * (qty / quantity);
      final cost = (qty * unitCost) + allocatedImportCost;
      final margin = revenue == 0 ? 0.0 : ((revenue - cost) / revenue) * 100;
      return AiDecisionScenario(
        title: '${qty.toStringAsFixed(0)} units/cartons',
        estimatedRevenue: revenue,
        estimatedCost: cost,
        margin: margin,
        cashImpact:
            'Cash outflow ${cost.toStringAsFixed(2)} before collection.',
        inventoryImpact: decisionType == AiFinancialDecisionType.pricingChange
            ? 'No direct stock increase.'
            : 'Inventory exposure increases by ${qty.toStringAsFixed(0)} units/cartons.',
        risk: margin < 15
            ? AiDecisionScenarioRisk.high
            : margin < 25
                ? AiDecisionScenarioRisk.medium
                : AiDecisionScenarioRisk.low,
      );
    }).toList();
  }

  String _fieldLabel(AiDecisionInputField field) {
    switch (field) {
      case AiDecisionInputField.quantity:
        return 'quantity';
      case AiDecisionInputField.unitCost:
        return 'unit cost';
      case AiDecisionInputField.expectedSellingPrice:
        return 'expected selling price';
      case AiDecisionInputField.currentPrice:
        return 'current price';
      case AiDecisionInputField.proposedPrice:
        return 'proposed price';
      case AiDecisionInputField.demandEvidence:
        return 'demand evidence';
      case AiDecisionInputField.customerPaymentHistory:
        return 'customer payment history';
      case AiDecisionInputField.paymentTerms:
        return 'payment terms';
      case AiDecisionInputField.importCosts:
        return 'shipping/customs/import costs';
      case AiDecisionInputField.timing:
        return 'timing';
    }
  }

  String _recommendationFor({
    required AiFinancialDecisionType decisionType,
    required double? margin,
    required AiDecisionRiskLevel risk,
  }) {
    if (risk == AiDecisionRiskLevel.high) {
      return 'I do not recommend approving this decision yet.';
    }
    if (margin != null && margin >= 25) {
      return 'This can be considered, but only with demand and cash discipline.';
    }
    return 'Proceed cautiously and compare a smaller scenario first.';
  }

  String _rationaleFor({
    required AiFinancialDecisionType decisionType,
    required double? margin,
    required AiDecisionRiskLevel risk,
  }) {
    final marginText = margin == null
        ? 'margin is not measurable'
        : 'margin is ${margin.toStringAsFixed(1)}%';
    return 'CFO assessment: $marginText and risk is ${risk.name}. The recommendation protects cash, margin, and exposure before committing.';
  }

  AiDecisionRiskLevel _riskFor({
    required AiFinancialDecisionType decisionType,
    required Map<AiDecisionInputField, dynamic> inputs,
  }) {
    final margin = _margin(inputs);
    final quantity = _number(inputs[AiDecisionInputField.quantity]) ?? 0;
    if (margin != null && margin < 15) return AiDecisionRiskLevel.high;
    if (quantity >= 300 &&
        (decisionType == AiFinancialDecisionType.inventoryPurchase ||
            decisionType == AiFinancialDecisionType.importShipment ||
            decisionType == AiFinancialDecisionType.stockIncrease)) {
      return AiDecisionRiskLevel.medium;
    }
    if (margin != null && margin < 25) return AiDecisionRiskLevel.medium;
    return AiDecisionRiskLevel.low;
  }

  double? _margin(Map<AiDecisionInputField, dynamic> inputs) {
    final unitCost = _number(inputs[AiDecisionInputField.unitCost]);
    final price = _number(inputs[AiDecisionInputField.expectedSellingPrice]) ??
        _number(inputs[AiDecisionInputField.proposedPrice]) ??
        _number(inputs[AiDecisionInputField.currentPrice]);
    if (unitCost == null || price == null || price <= 0) return null;
    return ((price - unitCost) / price) * 100;
  }

  AiShipmentDecisionInput _shipmentInputFromDecision(
    Map<AiDecisionInputField, dynamic> inputs,
  ) {
    return AiShipmentDecisionInput(
      purchaseCostPerUnit: _number(inputs[AiDecisionInputField.unitCost]) ?? 0,
      freightCost: _number(inputs[AiDecisionInputField.importCosts]) ?? 0,
      customsCost: 0,
      storageCost: 0,
      sellingPricePerUnit:
          _number(inputs[AiDecisionInputField.expectedSellingPrice]) ?? 0,
      expectedVolume: _number(inputs[AiDecisionInputField.quantity]) ?? 0,
      evidence: const [
        'conversation quantity',
        'conversation purchase cost',
        'conversation import costs',
        'conversation expected selling price',
      ],
      assumptions: const [
        'Conversation import costs are treated as combined freight/customs/storage until a detailed split is provided.',
      ],
    );
  }

  AiEvidenceConfidence _combinedConfidence(
    AiEvidenceConfidence evidenceConfidence,
    AiEvidenceConfidence shipmentConfidence,
  ) {
    if (evidenceConfidence == AiEvidenceConfidence.high &&
        shipmentConfidence == AiEvidenceConfidence.high) {
      return AiEvidenceConfidence.high;
    }
    if (shipmentConfidence == AiEvidenceConfidence.low) {
      return AiEvidenceConfidence.low;
    }
    return AiEvidenceConfidence.medium;
  }

  AiDecisionRiskLevel _decisionRiskFromTrade(AiTradeRiskLevel risk) {
    switch (risk) {
      case AiTradeRiskLevel.low:
        return AiDecisionRiskLevel.low;
      case AiTradeRiskLevel.medium:
        return AiDecisionRiskLevel.medium;
      case AiTradeRiskLevel.high:
      case AiTradeRiskLevel.critical:
        return AiDecisionRiskLevel.high;
    }
  }

  List<AiDecisionScenario> _shipmentScenarios(
    AiShipmentDecisionResult decision,
  ) {
    return decision.scenarios.map((scenario) {
      return AiDecisionScenario(
        title: scenario.name,
        estimatedRevenue: scenario.expectedRevenue,
        estimatedCost: scenario.totalLandedCost,
        margin: scenario.marginPercent,
        cashImpact:
            'Expected profit ${scenario.expectedProfit.toStringAsFixed(2)}.',
        inventoryImpact:
            'Recommendation: ${_tradeRecommendationLabel(scenario.recommendation)}.',
        risk: _scenarioRiskFromTrade(scenario.riskLevel),
      );
    }).toList();
  }

  AiDecisionScenarioRisk _scenarioRiskFromTrade(AiTradeRiskLevel risk) {
    switch (risk) {
      case AiTradeRiskLevel.low:
        return AiDecisionScenarioRisk.low;
      case AiTradeRiskLevel.medium:
        return AiDecisionScenarioRisk.medium;
      case AiTradeRiskLevel.high:
      case AiTradeRiskLevel.critical:
        return AiDecisionScenarioRisk.high;
    }
  }

  String _shipmentRationale(AiShipmentDecisionResult decision) {
    return [
      'Shipment profitability analysis:',
      'expected revenue ${decision.expectedRevenue.toStringAsFixed(2)}',
      'total landed cost ${decision.totalLandedCost.toStringAsFixed(2)}',
      'landed cost per unit ${decision.landedCostPerUnit.toStringAsFixed(2)}',
      'expected profit ${decision.expectedProfit.toStringAsFixed(2)}',
      'margin ${decision.marginPercent.toStringAsFixed(2)}%',
      'break-even point ${decision.breakEvenPointUnits} units',
      'risk ${decision.riskLabel}',
      'assumptions ${decision.assumptions.join('; ')}',
      'evidence ${decision.evidence.join('; ')}',
      'confidence ${decision.confidence.name.toUpperCase()}',
    ].join('. ');
  }

  String _tradeRecommendationLabel(AiTradeRecommendation recommendation) {
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

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
