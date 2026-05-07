class BranchModel {
  final String id;
  final String businessId;
  final String name;
  final String code;
  final String? address;
  final String? phone;
  final bool isMainBranch;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BranchModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.code,
    this.address,
    this.phone,
    this.isMainBranch = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  BranchModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? code,
    String? address,
    String? phone,
    bool? isMainBranch,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BranchModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isMainBranch: isMainBranch ?? this.isMainBranch,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'is_main_branch': isMainBranch ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id']?.toString() ?? '',
      businessId: map['businessId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      isMainBranch: (map['is_main_branch'] == 1 || map['is_main_branch'] == true),
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
