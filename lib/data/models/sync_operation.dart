enum SyncOperationType { create, update, delete }

enum SyncStatus { pending, processing, synced, failed }

class SyncOperation {
  final String id;
  final String entityName;
  final String entityId;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attemptCount;
  final String? lastError;
  final int priority;
  final int retryDelaySeconds;

  SyncOperation({
    required this.id,
    required this.entityName,
    required this.entityId,
    required this.type,
    required this.payload,
    this.status = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.attemptCount = 0,
    this.lastError,
    this.priority = 2,
    this.retryDelaySeconds = 0,
  });

  SyncOperation copyWith({
    SyncStatus? status,
    DateTime? updatedAt,
    int? attemptCount,
    String? lastError,
    Map<String, dynamic>? payload,
    int? priority,
    int? retryDelaySeconds,
    SyncOperationType? type,
  }) {
    return SyncOperation(
      id: id,
      entityName: entityName,
      entityId: entityId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      priority: priority ?? this.priority,
      retryDelaySeconds: retryDelaySeconds ?? this.retryDelaySeconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityName': entityName,
      'entityId': entityId,
      'type': type.name,
      'payload': payload,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'attemptCount': attemptCount,
      'lastError': lastError,
      'priority': priority,
      'retryDelaySeconds': retryDelaySeconds,
    };
  }

  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'],
      entityName: map['entityName'],
      entityId: map['entityId'],
      type: SyncOperationType.values.byName(map['type']),
      payload: Map<String, dynamic>.from(map['payload']),
      status: SyncStatus.values.byName(map['status']),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      attemptCount: map['attemptCount'] ?? 0,
      lastError: map['lastError'],
      priority: map['priority'] ?? 2,
      retryDelaySeconds: map['retryDelaySeconds'] ?? 0,
    );
  }
}
