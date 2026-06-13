import 'ai_decision_questionnaire.dart';
import 'ai_financial_decision_engine.dart';

class AiCfoPolicyDecision {
  final bool blocksRecommendation;
  final String rationale;

  const AiCfoPolicyDecision({
    required this.blocksRecommendation,
    required this.rationale,
  });
}

class AiCfoPolicy {
  AiCfoPolicyDecision evaluate({
    required AiFinancialDecisionType decisionType,
    required Map<AiDecisionInputField, dynamic> inputs,
  }) {
    if (_isLargeInventoryDecision(decisionType, inputs) &&
        (!inputs.containsKey(AiDecisionInputField.demandEvidence) ||
            _isWeakDemandEvidence(
              inputs[AiDecisionInputField.demandEvidence],
            ))) {
      return const AiCfoPolicyDecision(
        blocksRecommendation: true,
        rationale:
            'I do not recommend a large inventory commitment until demand evidence is confirmed.',
      );
    }

    if (decisionType == AiFinancialDecisionType.pricingChange) {
      final unitCost = _number(inputs[AiDecisionInputField.unitCost]);
      final proposedPrice = _number(inputs[AiDecisionInputField.proposedPrice]);
      if (unitCost != null &&
          proposedPrice != null &&
          proposedPrice <= unitCost) {
        return const AiCfoPolicyDecision(
          blocksRecommendation: true,
          rationale:
              'I do not recommend lowering price to or below cost because it destroys margin.',
        );
      }
    }

    if (decisionType == AiFinancialDecisionType.customerCreditSale &&
        !inputs.containsKey(AiDecisionInputField.customerPaymentHistory)) {
      return const AiCfoPolicyDecision(
        blocksRecommendation: true,
        rationale:
            'I cannot recommend credit exposure without customer payment history.',
      );
    }

    return const AiCfoPolicyDecision(
      blocksRecommendation: false,
      rationale: 'No CFO policy block detected.',
    );
  }

  bool _isLargeInventoryDecision(
    AiFinancialDecisionType decisionType,
    Map<AiDecisionInputField, dynamic> inputs,
  ) {
    final quantity = _number(inputs[AiDecisionInputField.quantity]) ?? 0;
    return (decisionType == AiFinancialDecisionType.inventoryPurchase ||
            decisionType == AiFinancialDecisionType.reorderInventory ||
            decisionType == AiFinancialDecisionType.importShipment ||
            decisionType == AiFinancialDecisionType.stockIncrease) &&
        quantity >= 300;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  bool _isWeakDemandEvidence(dynamic value) {
    final text = value?.toString().toLowerCase().trim() ?? '';
    if (text.isEmpty) return true;
    return text.contains('no confirmed') ||
        text.contains('not confirmed') ||
        text.contains('do not have confirmed') ||
        text.contains("don't have confirmed") ||
        text.contains('unknown') ||
        text.contains('no demand') ||
        text.contains('لا يوجد') ||
        text.contains('غير مؤكد');
  }
}
