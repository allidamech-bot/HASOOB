import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';

class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._();
  SyncQueueService._();

  final SyncQueueRepository _repository = SyncQueueRepository();
  final Random _random = Random();

  String _calculateFingerprint(String entityName, String entityId,
      SyncOperationType type, Map<String, dynamic> payload) {
    final data = '$entityName|$entityId|${type.name}|${jsonEncode(payload)}';
    return sha256.convert(utf8.encode(data)).toString();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[SyncQueue] $msg');
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
    final fingerprint =
        _calculateFingerprint(entityName, entityId, type, payload);
    _log('Enqueueing $type for $entityName:$entityId');

    final existing =
        await _repository.getPendingOperationByEntity(entityName, entityId);

    if (existing != null) {
      if (existing.type == type) {
        final mergedPayload = {...existing.payload, ...payload};
        final newFingerprint =
            _calculateFingerprint(entityName, entityId, type, mergedPayload);

        await _repository.updateOperation(existing.copyWith(
          payload: mergedPayload,
          updatedAt: DateTime.now(),
          priority: priority < existing.priority ? priority : existing.priority,
          fingerprint: newFingerprint,
          conflictStrategy: conflictStrategy,
          remoteVersion: remoteVersion,
        ));
        _requestAndScheduleSync();
        return;
      } else if (type == SyncOperationType.delete) {
        await _repository.updateOperation(existing.copyWith(
          type: SyncOperationType.delete,
          payload: {},
          status: SyncStatus.pending,
          updatedAt: DateTime.now(),
          priority: 1,
          fingerprint: _calculateFingerprint(
              entityName, entityId, SyncOperationType.delete, {}),
        ));
        _requestAndScheduleSync();
        return;
      }
    }

    final duplicate = await _repository.getOperationByFingerprint(fingerprint);
    if (duplicate != null && duplicate.status != SyncStatus.failed) {
      _requestAndScheduleSync();
      return;
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
    _requestAndScheduleSync();
  }

  void _requestAndScheduleSync() {
    SyncManager.instance.requestSync();
    if (!SyncManager.instance.isTestMode) {
      unawaited(SyncManager.instance.runIfRequested());
    }
  }

  Future<List<SyncOperation>> getPending() async {
    return _repository.getOperationsByStatus([
      SyncStatus.pending,
      SyncStatus.failed,
    ]);
  }

  Future<int> pendingQueueLength() {
    return _repository.countOperationsByStatus([
      SyncStatus.pending,
      SyncStatus.failed,
      SyncStatus.processing,
    ]);
  }

  Future<void> recoverInterruptedProcessing() async {
    final recovered = await _repository.resetProcessingToPending();
    if (recovered > 0) {
      SyncManager.instance.requestSync();
    }
  }

  Future<void> flushPendingLocalWrites() async {
    _log('Flushing local writes (WAL checkpoint simulation)');
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
      final baseDelay = pow(2, nextAttempt) * 10;
      final jitter = _random.nextInt((baseDelay * 0.3).toInt() + 1);
      nextRetryDelay = (baseDelay + jitter).toInt();
    }

    await _repository.updateOperation(operation.copyWith(
      status: status,
      lastError: error,
      conflictReason: conflictReason,
      remoteVersion: remoteVersion ?? operation.remoteVersion,
      updatedAt: DateTime.now(),
      attemptCount: status == SyncStatus.failed
          ? operation.attemptCount + 1
          : operation.attemptCount,
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
    final failed = await _repository
        .getOperationsByStatus([SyncStatus.failed, SyncStatus.conflict]);
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
    await _repository
        .getOperationsByStatus([SyncStatus.rejected]).then((ops) async {
      for (final op in ops) {
        await _repository.deleteOperation(op.id);
      }
    });
    SyncManager.instance.notifyListeners();
  }
}
