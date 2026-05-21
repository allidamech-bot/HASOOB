class AiActionLog {
  final String id;
  final String draftId;
  final String threadId;
  final String businessId;
  final String eventType;
  final String message;
  final String? payloadJson;
  final DateTime createdAt;

  const AiActionLog({
    required this.id,
    required this.draftId,
    required this.threadId,
    required this.businessId,
    required this.eventType,
    required this.message,
    this.payloadJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'draftId': draftId,
      'threadId': threadId,
      'businessId': businessId,
      'eventType': eventType,
      'message': message,
      'payloadJson': payloadJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiActionLog.fromMap(Map<String, dynamic> map) {
    return AiActionLog(
      id: map['id'] ?? '',
      draftId: map['draftId'] ?? '',
      threadId: map['threadId'] ?? '',
      businessId: map['businessId'] ?? '',
      eventType: map['eventType'] ?? '',
      message: map['message'] ?? '',
      payloadJson: map['payloadJson'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  AiActionLog copyWith({
    String? id,
    String? draftId,
    String? threadId,
    String? businessId,
    String? eventType,
    String? message,
    String? payloadJson,
    DateTime? createdAt,
  }) {
    return AiActionLog(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      threadId: threadId ?? this.threadId,
      businessId: businessId ?? this.businessId,
      eventType: eventType ?? this.eventType,
      message: message ?? this.message,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
