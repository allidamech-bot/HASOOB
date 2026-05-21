class AiActionDraft {
  final String id;
  final String threadId;
  final String businessId;
  final String userId;
  final String actionType;
  final String title;
  final String summary;
  final String? payloadJson;
  final String status;
  final String? validationErrorsJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiActionDraft({
    required this.id,
    required this.threadId,
    required this.businessId,
    required this.userId,
    required this.actionType,
    required this.title,
    required this.summary,
    this.payloadJson,
    required this.status,
    this.validationErrorsJson,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'businessId': businessId,
      'userId': userId,
      'actionType': actionType,
      'title': title,
      'summary': summary,
      'payloadJson': payloadJson,
      'status': status,
      'validationErrorsJson': validationErrorsJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiActionDraft.fromMap(Map<String, dynamic> map) {
    return AiActionDraft(
      id: map['id'] ?? '',
      threadId: map['threadId'] ?? '',
      businessId: map['businessId'] ?? '',
      userId: map['userId'] ?? '',
      actionType: map['actionType'] ?? '',
      title: map['title'] ?? '',
      summary: map['summary'] ?? '',
      payloadJson: map['payloadJson'],
      status: map['status'] ?? 'draft',
      validationErrorsJson: map['validationErrorsJson'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  AiActionDraft copyWith({
    String? id,
    String? threadId,
    String? businessId,
    String? userId,
    String? actionType,
    String? title,
    String? summary,
    String? payloadJson,
    String? status,
    String? validationErrorsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiActionDraft(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      businessId: businessId ?? this.businessId,
      userId: userId ?? this.userId,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      validationErrorsJson: validationErrorsJson ?? this.validationErrorsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
