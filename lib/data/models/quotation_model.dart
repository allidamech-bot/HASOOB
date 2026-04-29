class QuotationModel {
  final String id;
  final String businessId;
  final String customerName;
  final String quotationNumber;
  final double total;
  final String status; // draft, sent, approved
  final String? notes;
  final String? currencyCode;
  final String? pdfPath;
  final DateTime issueDate;
  final DateTime? expiryDate;

  const QuotationModel({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.quotationNumber,
    required this.total,
    required this.status,
    this.notes,
    this.currencyCode,
    this.pdfPath,
    required this.issueDate,
    this.expiryDate,
  });

  QuotationModel copyWith({
    String? id,
    String? businessId,
    String? customerName,
    String? quotationNumber,
    double? total,
    String? status,
    String? notes,
    String? currencyCode,
    String? pdfPath,
    DateTime? issueDate,
    DateTime? expiryDate,
  }) {
    return QuotationModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerName: customerName ?? this.customerName,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      total: total ?? this.total,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      currencyCode: currencyCode ?? this.currencyCode,
      pdfPath: pdfPath ?? this.pdfPath,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'customer_name': customerName,
      'quotation_number': quotationNumber,
      'total': total,
      'status': status,
      'notes': notes,
      'currency_code': currencyCode,
      'pdf_path': pdfPath,
      'issue_date': issueDate.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory QuotationModel.fromMap(Map<String, dynamic> map) {
    return QuotationModel(
      id: map['id']?.toString() ?? '',
      businessId: map['businessId']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? map['customer_id']?.toString() ?? '',
      quotationNumber: map['quotation_number']?.toString() ?? '',
      total: _toDouble(map['total']),
      status: map['status']?.toString() ?? 'draft',
      notes: map['notes']?.toString(),
      currencyCode: map['currency_code']?.toString(),
      pdfPath: map['pdf_path']?.toString(),
      issueDate: map['issue_date'] != null
          ? DateTime.tryParse(map['issue_date']) ?? DateTime.now()
          : DateTime.now(),
      expiryDate: map['expiry_date'] != null ? DateTime.tryParse(map['expiry_date']) : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
