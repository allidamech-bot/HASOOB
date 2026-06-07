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
    return AiProposalModel(
      actionType: map['actionType'] ?? 'unknown',
      explanation: map['explanation'] ?? '',
      confidenceScore: (map['confidenceScore'] ?? 0.0).toDouble(),
      inventoryPayload: map['inventoryPayload'],
      customerPayload: map['customerPayload'],
      financialPayload: map['financialPayload'],
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
