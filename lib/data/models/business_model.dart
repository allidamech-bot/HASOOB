class BusinessModel {
  final String id;
  final String name;
  final String? tradeName;
  final String? logoPath;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? registrationNumber;
  final String? defaultInvoiceNotes;
  final String? defaultQuotationNotes;
  final String? paymentTermsFooter;
  final String? branchId;
  final String ownerId;
  final DateTime createdAt;

  const BusinessModel({
    required this.id,
    required this.name,
    this.tradeName,
    this.logoPath,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.taxNumber,
    this.registrationNumber,
    this.defaultInvoiceNotes,
    this.defaultQuotationNotes,
    this.paymentTermsFooter,
    this.branchId,
    required this.ownerId,
    required this.createdAt,
  });

  BusinessModel copyWith({
    String? id,
    String? name,
    String? tradeName,
    String? logoPath,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? taxNumber,
    String? registrationNumber,
    String? defaultInvoiceNotes,
    String? defaultQuotationNotes,
    String? paymentTermsFooter,
    String? branchId,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tradeName: tradeName ?? this.tradeName,
      logoPath: logoPath ?? this.logoPath,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      defaultInvoiceNotes: defaultInvoiceNotes ?? this.defaultInvoiceNotes,
      defaultQuotationNotes: defaultQuotationNotes ?? this.defaultQuotationNotes,
      paymentTermsFooter: paymentTermsFooter ?? this.paymentTermsFooter,
      branchId: branchId ?? this.branchId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': name,
      'trade_name': tradeName,
      'logo_path': logoPath,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'registration_number': registrationNumber,
      'default_invoice_notes': defaultInvoiceNotes,
      'default_quotation_notes': defaultQuotationNotes,
      'payment_terms_footer': paymentTermsFooter,
      'branch_id': branchId,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      id: map['id']?.toString() ?? '',
      name: map['business_name']?.toString() ?? map['name']?.toString() ?? '',
      tradeName: map['trade_name']?.toString(),
      logoPath: map['logo_path']?.toString(),
      phone: map['phone']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      taxNumber: map['tax_number']?.toString(),
      registrationNumber: map['registration_number']?.toString(),
      defaultInvoiceNotes: map['default_invoice_notes']?.toString(),
      defaultQuotationNotes: map['default_quotation_notes']?.toString(),
      paymentTermsFooter: map['payment_terms_footer']?.toString(),
      branchId: map['branch_id']?.toString(),
      ownerId: map['ownerId']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
