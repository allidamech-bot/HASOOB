import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceModel {
  final String id;
  final String customerId;
  final String customerName;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double total;
  final String status; // 'draft' | 'sent' | 'paid' | 'overdue'
  final DateTime? createdAt;
  final DateTime? dueDate;

  InvoiceModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.status,
    this.createdAt,
    this.dueDate,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InvoiceModel(
      id: documentId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'draft',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'items': items,
      'subtotal': subtotal,
      'total': total,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    };
  }
}
