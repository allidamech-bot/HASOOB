class BranchModel {
  final String id;
  final String businessId;
  final String name;
  final String location;

  const BranchModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.location,
  });

  BranchModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? location,
  }) {
    return BranchModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'location': location,
    };
  }

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      location: map['location'] ?? '',
    );
  }
}
