import 'sync_queue_service.dart';
import '../models/sync_operation.dart';
import 'sync_service.dart';
import 'cloud_sync_service.dart';

class SyncEngine {
  final SyncQueueService _syncQueueService;
  final SyncService _syncService;
  
  SyncEngine({
    SyncQueueService? syncQueueService,
    SyncService? syncService,
  })  : _syncQueueService = syncQueueService ?? SyncQueueService.instance,
        _syncService = syncService ?? CloudSyncService.instance;

  bool _isProcessing = false;
  static const int _maxRetries = 3;

  /// Processes all pending sync operations in the queue sequentially.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final operations = await _syncQueueService.getPending();
      
      for (final operation in operations) {
        // Skip operations that have reached the maximum retry limit
        if (operation.attemptCount >= _maxRetries) {
          continue;
        }

        await _processOperation(operation);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Internal method to process a single operation by calling the appropriate cloud service.
  Future<void> _processOperation(SyncOperation operation) async {
    // Mark as processing
    await _syncQueueService.updateStatus(operation, SyncStatus.processing);

    try {
      switch (operation.entityName) {
        case 'products':
          await _processProduct(operation);
          break;
        case 'customers':
          await _processCustomer(operation);
          break;
        default:
          throw UnimplementedError('Sync for entity ${operation.entityName} not implemented');
      }

      // Mark as synced on success
      await _syncQueueService.updateStatus(operation, SyncStatus.synced);
    } catch (e) {
      // Mark as failed. SyncQueueService handles incrementing attemptCount.
      await _syncQueueService.updateStatus(
        operation, 
        SyncStatus.failed, 
        error: e.toString(),
      );
    }
  }

  Future<void> _processProduct(SyncOperation operation) async {
    if (operation.type == SyncOperationType.delete) {
      await _syncService.deleteProduct(operation.entityId);
    } else {
      await _syncService.upsertProduct(operation.payload);
    }
  }

  Future<void> _processCustomer(SyncOperation operation) async {
    if (operation.type == SyncOperationType.delete) {
      await _syncService.deleteCustomer(operation.entityId);
    } else {
      await _syncService.upsertCustomer(operation.payload);
    }
  }
}
