class AiProposalModel {
  final String actionType; // 'purchase' | 'sale' | 'payment_receipt' | 'unknown'
  final String explanation; 
  final double confidenceScore; 
  final Map<String, dynamic>? inventoryPayload; 
  final Map<String, dynamic>? customerPayload;
  final Map<String, dynamic>? financialPayload;

  AiProposalModel({
    required this.actionType,
    required this.explanation,
    required this.confidenceScore,
    this.inventoryPayload,
    this.customerPayload,
    this.financialPayload,
  });

  factory AiProposalModel.fromMap(Map<String, dynamic> map) {
    // Defensive normalization for inventory payload nested elements
    Map<String, dynamic>? sanitizedInventory;
    if (map['inventoryPayload'] != null) {
      final inv = Map<String, dynamic>.from(map['inventoryPayload']);
      sanitizedInventory = {
        ...inv,
        'quantity': inv['quantity'] != null ? (inv['quantity'] as num).toInt() : 0,
        'costPrice': inv['costPrice'] != null ? (inv['costPrice'] as num).toDouble() : 0.0,
      };
    }

    // Defensive normalization for financial payload nested elements
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

    return AiProposalModel(
      actionType: map['actionType'] ?? 'unknown',
      explanation: map['explanation'] ?? '',
      confidenceScore: map['confidenceScore'] != null ? (map['confidenceScore'] as num).toDouble() : 0.0,
      inventoryPayload: sanitizedInventory,
      customerPayload: map['customerPayload'] != null ? Map<String, dynamic>.from(map['customerPayload']) : null,
      financialPayload: sanitizedFinancial,
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
    };
  }
}
