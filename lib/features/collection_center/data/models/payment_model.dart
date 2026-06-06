import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String invoiceId;
  final String customerId;
  final String customerName;
  final double amount;
  final String method; // 'cash' | 'bank'
  final DateTime? createdAt;

  PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.method,
    this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PaymentModel(
      id: documentId,
      invoiceId: map['invoiceId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      method: map['method'] ?? 'cash',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'customerId': customerId,
      'customerName': customerName,
      'amount': amount,
      'method': method,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
