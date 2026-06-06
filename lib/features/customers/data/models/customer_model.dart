import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String status; // 'active' | 'inactive'
  final DateTime? createdAt;
  final List<String> tags;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    this.createdAt,
    required this.tags,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CustomerModel(
      id: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'tags': tags,
    };
  }
}
