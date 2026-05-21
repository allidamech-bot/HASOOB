class AiMemoryItem {
  final String id;
  final String businessId;
  final String userId;
  final String type;
  final String key;
  final String value;
  final double confidence;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiMemoryItem({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.type,
    required this.key,
    required this.value,
    required this.confidence,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'userId': userId,
      'type': type,
      'key': key,
      'value': value,
      'confidence': confidence,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiMemoryItem.fromMap(Map<String, dynamic> map) {
    return AiMemoryItem(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      confidence: map['confidence']?.toDouble() ?? 1.0,
      source: map['source'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  AiMemoryItem copyWith({
    String? id,
    String? businessId,
    String? userId,
    String? type,
    String? key,
    String? value,
    double? confidence,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiMemoryItem(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      key: key ?? this.key,
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
