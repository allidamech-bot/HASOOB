class InvoiceModel {
  final String id;
  final String businessId;
  final String customerName;
  final double total;
  final DateTime createdAt;

  const InvoiceModel({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.total,
    required this.createdAt,
  });

  InvoiceModel copyWith({
    String? id,
    String? businessId,
    String? customerName,
    double? total,
    DateTime? createdAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerName: customerName ?? this.customerName,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'customerName': customerName,
      'total': total,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      customerName: map['customerName'] ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
