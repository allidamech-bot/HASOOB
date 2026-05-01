import 'sync_queue_service.dart';
import '../models/sync_operation.dart';

class SyncEngine {
  static final SyncEngine instance = SyncEngine._();
  SyncEngine._();

  final SyncQueueService _syncQueueService = SyncQueueService.instance;
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

  /// Internal method to process a single operation with simulation logic.
  Future<void> _processOperation(SyncOperation operation) async {
    // Mark as processing
    await _syncQueueService.updateStatus(operation, SyncStatus.processing);

    try {
      // In-memory execution simulation:
      // operation with entityId containing "fail" => mark failed
      if (operation.entityId.contains('fail')) {
        throw Exception('Simulated sync failure for ${operation.entityId}');
      }

      // Valid operation => mark synced
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
}
