class AiProposalModel {
  final String actionType; // 'purchase' | 'sale' | 'pricing_simulation' | 'unknown'
  final String explanation; 
  final double confidenceScore; 
  final Map<String, dynamic>? inventoryPayload; 
  final Map<String, dynamic>? customerPayload;
  final Map<String, dynamic>? financialPayload;
  final Map<String, dynamic>? pricingPayload; // New premium expansion for dynamic pricing simulations

  AiProposalModel({
    required this.actionType,
    required this.explanation,
    required this.confidenceScore,
    this.inventoryPayload,
    this.customerPayload,
    this.financialPayload,
    this.pricingPayload,
  });

  factory AiProposalModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? sanitizedInventory;
    if (map['inventoryPayload'] != null) {
      final inv = Map<String, dynamic>.from(map['inventoryPayload']);
      sanitizedInventory = {
        ...inv,
        'quantity': inv['quantity'] != null ? (inv['quantity'] as num).toInt() : 0,
        'costPrice': inv['costPrice'] != null ? (inv['costPrice'] as num).toDouble() : 0.0,
      };
    }

    Map<String, dynamic>? sanitizedFinancial;
    if (map['financialPayload'] != null) {
      final fin = Map<String, dynamic>.from(map['financialPayload']);
      sanitizedFinancial = {
        ...fin,
        'totalAmount': fin['totalAmount'] != null ? (fin['totalAmount'] as num).toDouble() : 0.0,
        'amountPaid': fin['amountPaid'] != null ? (fin['amountPaid'] as num).toDouble() : 0.0,
        'isFullyPaid': fin['isFullyPaid'] ?? false,
      };
    }

    // Secure extraction for the predictive pricing metrics
    Map<String, dynamic>? sanitizedPricing;
    if (map['pricingPayload'] != null) {
      final prc = Map<String, dynamic>.from(map['pricingPayload']);
      sanitizedPricing = {
        'suggestedPricePerUnit': prc['suggestedPricePerUnit'] != null ? (prc['suggestedPricePerUnit'] as num).toDouble() : 0.0,
        'landedCostPerUnit': prc['landedCostPerUnit'] != null ? (prc['landedCostPerUnit'] as num).toDouble() : 0.0,
        'targetMarginPercentage': prc['targetMarginPercentage'] != null ? (prc['targetMarginPercentage'] as num).toDouble() : 0.0,
        'estimatedTotalBoxes': prc['estimatedTotalBoxes'] != null ? (prc['estimatedTotalBoxes'] as num).toInt() : 0,
        'shippingCost': prc['shippingCost'] != null ? (prc['shippingCost'] as num).toDouble() : 0.0,
        'customsCost': prc['customsCost'] != null ? (prc['customsCost'] as num).toDouble() : 0.0,
        'destination': prc['destination'] ?? '',
      };
    }

    return AiProposalModel(
      actionType: map['actionType'] ?? 'unknown',
      explanation: map['explanation'] ?? '',
      confidenceScore: map['confidenceScore'] != null ? (map['confidenceScore'] as num).toDouble() : 0.0,
      inventoryPayload: sanitizedInventory,
      customerPayload: map['customerPayload'] != null ? Map<String, dynamic>.from(map['customerPayload']) : null,
      financialPayload: sanitizedFinancial,
      pricingPayload: sanitizedPricing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actionType': actionType,
      'explanation': explanation,
      'confidenceScore': confidenceScore,
      'inventoryPayload': inventoryPayload,
      'customerPayload': customerPayload,
      'financialPayload': financialPayload,
      'pricingPayload': pricingPayload,
    };
  }
}
