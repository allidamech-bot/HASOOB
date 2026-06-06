import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final String sku;
  final int quantity;
  final double price;
  final String category;
  final DateTime? updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.price,
    required this.category,
    this.updatedAt,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryItem(
      id: documentId,
      name: map['name'] ?? '',
      sku: map['sku'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      price: (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sku': sku,
      'quantity': quantity,
      'price': price,
      'category': category,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
