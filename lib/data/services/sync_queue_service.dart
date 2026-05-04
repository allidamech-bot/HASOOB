
import 'dart:math';
import '../models/sync_operation.dart';
import '../repositories/sync_queue_repository.dart';
import 'sync_manager.dart';

class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._();
  SyncQueueService._();

  final SyncQueueRepository _repository = SyncQueueRepository();
  final Random _random = Random();

  Future<void> enqueue({
    required String entityName,
    required String entityId,
    required SyncOperationType type,
    required Map<String, dynamic> payload,
    int priority = 2,
  }) async {
    // Duplicate protection
    final existing = await _repository.getPendingOperationByEntity(entityName, entityId);
    
    if (existing != null) {
      // If we have a pending operation for the same entity
      if (existing.type == type) {
        // Same type: Update existing operation with new payload and bump updatedAt
        final mergedPayload = {...existing.payload, ...payload};
        await _repository.updateOperation(existing.copyWith(
          payload: mergedPayload,
          updatedAt: DateTime.now(),
          priority: priority < existing.priority ? priority : existing.priority,
        ));
        SyncManager.instance.requestSync();
        return;
      } else if (type == SyncOperationType.delete) {
        // If new op is delete, it overrides any pending create/update
        await _repository.updateOperation(existing.copyWith(
          type: SyncOperationType.delete,
          payload: {}, // No payload needed for delete usually
          updatedAt: DateTime.now(),
          priority: 1, // Higher priority for deletes
        ));
        SyncManager.instance.requestSync();
        return;
      }
      // If existing was delete and new is update... that's weird but possible if recreated.
      // For now, we'll just allow multiple if types differ and not covered by logic above.
    }

    final operation = SyncOperation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      entityName: entityName,
      entityId: entityId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      priority: priority,
    );

    await _repository.enqueue(operation);
    
    // Request sync status update
    SyncManager.instance.requestSync();
  }
  
  Future<List<SyncOperation>> getPending() async {
    return _repository.getOperationsByStatus([
      SyncStatus.pending,
      SyncStatus.failed,
    ]);
  }
  
  Future<List<SyncOperation>> getAll() => _repository.getAllOperations();
  
  Future<void> updateStatus(SyncOperation operation, SyncStatus status, {String? error}) async {
    int? nextRetryDelay;
    if (status == SyncStatus.failed) {
      final nextAttempt = operation.attemptCount + 1;
      // Exponential backoff: 2^attempt * 10 seconds
      // attempt 1 -> 20s
      // attempt 2 -> 40s
      // attempt 3 -> 80s
      final baseDelay = pow(2, nextAttempt) * 10;
      
      // Add jitter: 0 to 30% of base delay
      final jitter = _random.nextInt((baseDelay * 0.3).toInt() + 1);
      nextRetryDelay = (baseDelay + jitter).toInt();
    }

    await _repository.updateOperation(operation.copyWith(
      status: status,
      lastError: error,
      updatedAt: DateTime.now(),
      attemptCount: status == SyncStatus.failed ? operation.attemptCount + 1 : operation.attemptCount,
      retryDelaySeconds: nextRetryDelay,
    ));
  }

  Future<void> delete(String id) => _repository.deleteOperation(id);

  Future<void> clearSynced() async {
    await _repository.clearSynced();
    SyncManager.instance.notifyListeners();
  }
}
