class AuthUserModel {
  final String id;
  final String email;
  final String? displayName;
  final String businessId;
  final String role; // owner, manager, employee

  const AuthUserModel({
    required this.id,
    required this.email,
    this.displayName,
    required this.businessId,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'businessId': businessId,
      'role': role,
    };
  }

  factory AuthUserModel.fromMap(Map<String, dynamic> map) {
    return AuthUserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      businessId: map['businessId'] ?? '',
      role: map['role'] ?? 'employee',
    );
  }

  AuthUserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? businessId,
    String? role,
  }) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      businessId: businessId ?? this.businessId,
      role: role ?? this.role,
    );
  }
}
