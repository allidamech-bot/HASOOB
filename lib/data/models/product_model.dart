class ProductModel {
  final String id;
  final String businessId;
  final String name;
  final double price;
  final double quantity;

  const ProductModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  ProductModel copyWith({
    String? id,
    String? businessId,
    String? name,
    double? price,
    double? quantity,
  }) {
    return ProductModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
