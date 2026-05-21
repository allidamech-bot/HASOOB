class AiThread {
  final String id;
  final String businessId;
  final String userId;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiThread({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'userId': userId,
      'title': title,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiThread.fromMap(Map<String, dynamic> map) {
    return AiThread(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  AiThread copyWith({
    String? id,
    String? businessId,
    String? userId,
    String? title,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiThread(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
