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
  final bool _isTestMode;
  
  SyncEngine({
    SyncQueueService? syncQueueService,
    SyncService? syncService,
    AnalyticsService? analytics,
    bool? isTestMode,
  })  : _syncQueueService = syncQueueService ?? SyncQueueService.instance,
        _syncService = syncService ?? CloudSyncService.instance,
        _analytics = analytics ?? NoOpAnalyticsService(),
        _isTestMode = isTestMode ?? identical(0, 0.0);

  bool _isProcessing = false;
  static const int _maxRetries = 3;
  static const int _batchSize = 5;

  /// Processes all pending sync operations in the queue sequentially in batches.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _logger.log('Starting queue processing');

    try {
      while (true) {
        final operations = await _syncQueueService.getPending();
        
        // Filter out operations that are still in retry delay or reached max retries
        final now = DateTime.now();
        final eligibleOperations = operations.where((op) {
          if (op.attemptCount >= _maxRetries) return false;
          
          if (!_isTestMode && op.retryDelaySeconds > 0) {
            final nextAllowedTime = op.updatedAt.add(Duration(seconds: op.retryDelaySeconds));
            if (now.isBefore(nextAllowedTime)) return false;
          }
          
          return true;
        }).take(_batchSize).toList();

        if (eligibleOperations.isEmpty) {
          _logger.log('No more eligible operations to process');
          break;
        }

        _logger.log('Processing batch of ${eligibleOperations.length} operations');
        
        for (final operation in eligibleOperations) {
          await _processOperation(operation);
        }
        
        // If we processed less than a full batch, we might be done or only have ineligible ops left
        if (eligibleOperations.length < _batchSize) {
          break;
        }
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
      if (operation.type == SyncOperationType.delete) {
        await _syncService.delete(operation.entityName, operation.entityId);
      } else {
        await _syncService.upsert(operation.entityName, operation.payload);
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
}
