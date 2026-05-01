import 'package:uuid/uuid.dart';
import '../models/sync_operation.dart';
import '../repositories/sync_queue_repository.dart';

class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._();
  SyncQueueService._();

  final SyncQueueRepository _repository = SyncQueueRepository();
  final _uuid = const Uuid();

  Future<void> enqueue({
    required String entityName,
    required String entityId,
    required SyncOperationType type,
    required Map<String, dynamic> payload,
  }) async {
    final operation = SyncOperation(
      id: _uuid.v4(),
      entityName: entityName,
      entityId: entityId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.enqueue(operation);
  }
  
  Future<List<SyncOperation>> getPending() => _repository.getPendingOperations();
  
  Future<void> updateStatus(SyncOperation operation, SyncStatus status, {String? error}) async {
    await _repository.updateOperation(operation.copyWith(
      status: status,
      lastError: error,
      updatedAt: DateTime.now(),
      attemptCount: status == SyncStatus.failed ? operation.attemptCount + 1 : operation.attemptCount,
    ));
  }

  Future<void> delete(String id) => _repository.deleteOperation(id);
}
