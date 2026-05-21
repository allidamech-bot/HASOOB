class AiMessage {
  final String id;
  final String threadId;
  final String businessId;
  final String role;
  final String content;
  final String? metadataJson;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.threadId,
    required this.businessId,
    required this.role,
    required this.content,
    this.metadataJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'businessId': businessId,
      'role': role,
      'content': content,
      'metadataJson': metadataJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'] ?? '',
      threadId: map['threadId'] ?? '',
      businessId: map['businessId'] ?? '',
      role: map['role'] ?? '',
      content: map['content'] ?? '',
      metadataJson: map['metadataJson'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  AiMessage copyWith({
    String? id,
    String? threadId,
    String? businessId,
    String? role,
    String? content,
    String? metadataJson,
    DateTime? createdAt,
  }) {
    return AiMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      businessId: businessId ?? this.businessId,
      role: role ?? this.role,
      content: content ?? this.content,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
