
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/sync_operation.dart';
import '../repositories/sync_queue_repository.dart';
import 'sync_manager.dart';

class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._();
  SyncQueueService._();

  final SyncQueueRepository _repository = SyncQueueRepository();
  final Random _random = Random();

  String _calculateFingerprint(String entityName, String entityId, SyncOperationType type, Map<String, dynamic> payload) {
    final data = '$entityName|$entityId|${type.name}|${jsonEncode(payload)}';
    return sha256.convert(utf8.encode(data)).toString();
  }

  Future<void> enqueue({
    required String entityName,
    required String entityId,
    required SyncOperationType type,
    required Map<String, dynamic> payload,
    int priority = 2,
    SyncConflictStrategy conflictStrategy = SyncConflictStrategy.lastWriteWins,
    int? remoteVersion,
  }) async {
    final fingerprint = _calculateFingerprint(entityName, entityId, type, payload);

    final existing = await _repository.getPendingOperationByEntity(entityName, entityId);
    
    if (existing != null) {
      // Smart skip/collapse logic
      if (existing.type == type) {
        // Same type: Update existing operation with new payload and bump updatedAt
        final mergedPayload = {...existing.payload, ...payload};
        final newFingerprint = _calculateFingerprint(entityName, entityId, type, mergedPayload);
        
        await _repository.updateOperation(existing.copyWith(
          payload: mergedPayload,
          updatedAt: DateTime.now(),
          priority: priority < existing.priority ? priority : existing.priority,
          fingerprint: newFingerprint,
          conflictStrategy: conflictStrategy,
          remoteVersion: remoteVersion,
        ));
        SyncManager.instance.requestSync();
        return;
      } else if (type == SyncOperationType.delete) {
        // If new op is delete, it overrides any pending update or create
        await _repository.updateOperation(existing.copyWith(
          type: SyncOperationType.delete,
          payload: {}, // No payload needed for delete usually
          status: SyncStatus.pending, // Reset status to pending in case it was failed
          updatedAt: DateTime.now(),
          priority: 1, // Higher priority for deletes
          fingerprint: _calculateFingerprint(entityName, entityId, SyncOperationType.delete, {}),
        ));
        SyncManager.instance.requestSync();
        return;
      }
    }

    // Duplicate identical operations protection
    final duplicate = await _repository.getOperationByFingerprint(fingerprint);
    if (duplicate != null && duplicate.status != SyncStatus.failed) {
      return; // Skip if already pending or synced with same fingerprint
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
      fingerprint: fingerprint,
      conflictStrategy: conflictStrategy,
      remoteVersion: remoteVersion,
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
  
  Future<void> updateStatus(
    SyncOperation operation, 
    SyncStatus status, {
    String? error, 
    String? conflictReason,
    int? remoteVersion,
  }) async {
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
      conflictReason: conflictReason,
      remoteVersion: remoteVersion ?? operation.remoteVersion,
      updatedAt: DateTime.now(),
      attemptCount: status == SyncStatus.failed ? operation.attemptCount + 1 : operation.attemptCount,
      retryDelaySeconds: nextRetryDelay,
    ));
  }

  Future<void> delete(String id) => _repository.deleteOperation(id);

  Future<void> retryOperation(String id) async {
    final all = await _repository.getAllOperations();
    final op = all.firstWhere((o) => o.id == id);
    
    if (op.status != SyncStatus.failed && op.status != SyncStatus.conflict) {
      return;
    }

    await _repository.updateOperation(op.copyWith(
      status: SyncStatus.pending,
      attemptCount: 0,
      retryDelaySeconds: 0,
    ));
    SyncManager.instance.requestSync();
  }

  Future<void> retryAllFailed() async {
    final failed = await _repository.getOperationsByStatus([SyncStatus.failed, SyncStatus.conflict]);
    for (final op in failed) {
      await _repository.updateOperation(op.copyWith(
        status: SyncStatus.pending,
        attemptCount: 0,
        retryDelaySeconds: 0,
      ));
    }
    SyncManager.instance.requestSync();
  }

  Future<void> clearSynced() async {
    await _repository.clearSynced();
    SyncManager.instance.notifyListeners();
  }

  Future<void> resolveConflictUseLocal(String id) async {
    final all = await _repository.getAllOperations();
    final op = all.firstWhere((o) => o.id == id);
    
    if (op.status != SyncStatus.conflict) return;

    await _repository.updateOperation(op.copyWith(
      status: SyncStatus.pending,
      remoteVersion: op.remoteVersion,
      attemptCount: 0,
      retryDelaySeconds: 0,
    ));
    SyncManager.instance.requestSync();
  }

  Future<void> resolveConflictUseRemote(String id) async {
    final all = await _repository.getAllOperations();
    final op = all.firstWhere((o) => o.id == id);
    
    if (op.status != SyncStatus.conflict) return;

    await _repository.deleteOperation(id);
    SyncManager.instance.requestSync();
  }

  Future<void> clearRejected() async {
    await _repository.getOperationsByStatus([SyncStatus.rejected]).then((ops) async {
      for (final op in ops) {
        await _repository.deleteOperation(op.id);
      }
    });
    SyncManager.instance.notifyListeners();
  }
}
