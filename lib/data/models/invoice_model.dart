class InvoiceModel {
  final String id;
  final String businessId;
  final String customerName;
  final String invoiceNumber;
  final String status;
  final double total;
  final double paidAmount;
  final double remainingAmount;
  final String? currencyCode;
  final String? notes;
  final String? pdfPath;
  final DateTime issueDate;
  final DateTime? dueDate;

  const InvoiceModel({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.invoiceNumber,
    required this.status,
    required this.total,
    required this.paidAmount,
    required this.remainingAmount,
    this.currencyCode,
    this.notes,
    this.pdfPath,
    required this.issueDate,
    this.dueDate,
  });

  InvoiceModel copyWith({
    String? id,
    String? businessId,
    String? customerName,
    String? invoiceNumber,
    String? status,
    double? total,
    double? paidAmount,
    double? remainingAmount,
    String? currencyCode,
    String? notes,
    String? pdfPath,
    DateTime? issueDate,
    DateTime? dueDate,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerName: customerName ?? this.customerName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      notes: notes ?? this.notes,
      pdfPath: pdfPath ?? this.pdfPath,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'customer_name': customerName,
      'invoice_number': invoiceNumber,
      'status': status,
      'total': total,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'currency_code': currencyCode,
      'notes': notes,
      'pdf_path': pdfPath,
      'issue_date': issueDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id']?.toString() ?? '',
      businessId: map['businessId']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? map['customer_id']?.toString() ?? '',
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      total: _toDouble(map['total']),
      paidAmount: _toDouble(map['paid_amount']),
      remainingAmount: _toDouble(map['remaining_amount']),
      currencyCode: map['currency_code']?.toString(),
      notes: map['notes']?.toString(),
      pdfPath: map['pdf_path']?.toString(),
      issueDate: map['issue_date'] != null
          ? DateTime.tryParse(map['issue_date']) ?? DateTime.now()
          : DateTime.now(),
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date']) : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
