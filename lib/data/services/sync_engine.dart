import 'sync_queue_service.dart';
import '../models/sync_operation.dart';
import 'sync_service.dart';
import 'cloud_sync_service.dart';
import 'sync_log_service.dart';
import 'analytics_service.dart';

class SyncEngine {
  final SyncQueueService _syncQueueService;
  final SyncService _syncService;
  final AnalyticsService _analytics;
  final SyncLogService _logger = SyncLogService.instance;
  
  SyncEngine({
    SyncQueueService? syncQueueService,
    SyncService? syncService,
    AnalyticsService? analytics,
  })  : _syncQueueService = syncQueueService ?? SyncQueueService.instance,
        _syncService = syncService ?? CloudSyncService.instance,
        _analytics = analytics ?? NoOpAnalyticsService();

  bool _isProcessing = false;
  static const int _maxRetries = 3;

  /// Processes all pending sync operations in the queue sequentially.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _logger.log('Starting queue processing');

    try {
      final operations = await _syncQueueService.getPending();
      _logger.log('Found ${operations.length} pending operations');
      
      for (final operation in operations) {
        // Skip operations that have reached the maximum retry limit
        if (operation.attemptCount >= _maxRetries) {
          _logger.log(
            'Skipping operation ${operation.id} (Max retries reached)',
            level: SyncLogLevel.warning,
          );
          continue;
        }

        await _processOperation(operation);
      }
    } catch (e) {
      _logger.log('Critical error in processQueue', level: SyncLogLevel.error, details: e.toString());
    } finally {
      _isProcessing = false;
      _logger.log('Queue processing finished');
    }
  }

  /// Internal method to process a single operation by calling the appropriate cloud service.
  Future<void> _processOperation(SyncOperation operation) async {
    _logger.log('Processing ${operation.entityName}:${operation.type.name} (${operation.id})');
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
      _logger.log('Successfully synced ${operation.id}');
      
      _analytics.logEvent(
        name: 'sync_success',
        parameters: {
          'entity': operation.entityName,
          'type': operation.type.name,
          'attempts': operation.attemptCount + 1,
        },
      );
    } catch (e) {
      _logger.log(
        'Failed to sync ${operation.id}',
        level: SyncLogLevel.error,
        details: e.toString(),
      );
      // Mark as failed. SyncQueueService handles incrementing attemptCount.
      await _syncQueueService.updateStatus(
        operation, 
        SyncStatus.failed, 
        error: e.toString(),
      );

      _analytics.logEvent(
        name: 'sync_failure',
        parameters: {
          'entity': operation.entityName,
          'type': operation.type.name,
          'error': e.toString().substring(0, (e.toString().length > 100 ? 100 : e.toString().length)),
          'attempts': operation.attemptCount + 1,
        },
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
