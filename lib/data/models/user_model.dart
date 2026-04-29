class UserModel {
  final String id;
  final String businessId;
  final String name;
  final String role; // owner, manager, employee

  const UserModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.role,
  });

  UserModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'role': role,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
    );
  }
}
