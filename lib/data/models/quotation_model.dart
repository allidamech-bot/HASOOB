class QuotationModel {
  final String id;
  final String businessId;
  final String customerName;
  final double total;
  final String status; // draft, sent, approved
  final DateTime createdAt;

  const QuotationModel({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  QuotationModel copyWith({
    String? id,
    String? businessId,
    String? customerName,
    double? total,
    String? status,
    DateTime? createdAt,
  }) {
    return QuotationModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerName: customerName ?? this.customerName,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'customerName': customerName,
      'total': total,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QuotationModel.fromMap(Map<String, dynamic> map) {
    return QuotationModel(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      customerName: map['customerName'] ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
