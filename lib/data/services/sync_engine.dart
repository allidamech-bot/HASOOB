import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'backend_adapter.dart';
import 'sync_log_service.dart';
import 'analytics_service.dart';
import 'sync_service.dart';
import 'legacy_sync_adapter.dart';

class SyncEngine {
  final SyncQueueService _syncQueueService;
  final BackendAdapter _backendAdapter;
  final AnalyticsService _analytics;
  final SyncLogService _logger = SyncLogService.instance;
  final bool _isTestMode;
  
  SyncEngine({
    SyncQueueService? syncQueueService,
    BackendAdapter? backendAdapter,
    SyncService? syncService,
    AnalyticsService? analytics,
    bool? isTestMode,
  })  : _syncQueueService = syncQueueService ?? SyncQueueService.instance,
        _backendAdapter = backendAdapter ?? 
            (syncService != null ? LegacySyncAdapter(syncService) : NoOpBackendAdapter()),
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
          if (op.status == SyncStatus.rejected || op.status == SyncStatus.conflict) return false;
          
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
    
    // Integrity validation
    if (operation.entityId.isEmpty) {
      await _syncQueueService.updateStatus(operation, SyncStatus.rejected, error: 'Missing entityId');
      return;
    }

    // Mark as processing
    await _syncQueueService.updateStatus(operation, SyncStatus.processing);

    try {
      // Conflict Detection logic
      final remoteData = await _backendAdapter.fetchRemoteData(operation.entityName, operation.entityId);
      final remoteVersion = _toInt(remoteData?['remoteVersion'] ?? remoteData?['version']);
      
      if (remoteVersion > 0) {
        final localVersion = operation.remoteVersion ?? 0;
        
        if (remoteVersion > localVersion) {
          // Remote is newer than what we base our update on.
          _logger.log('Conflict detected for ${operation.entityId}: Remote version $remoteVersion > Local base version $localVersion');
          
          if (operation.conflictStrategy == SyncConflictStrategy.manualReview) {
            await _syncQueueService.updateStatus(
              operation, 
              SyncStatus.conflict, 
              conflictReason: 'Remote version ($remoteVersion) is newer than local base ($localVersion).',
              remoteVersion: remoteVersion,
            );
            return;
          } else if (operation.conflictStrategy == SyncConflictStrategy.merge) {
            // Merge logic would go here, for now fallback to lastWriteWins or fail
            _logger.log('Merge strategy requested but not fully implemented. Falling back to lastWriteWins.');
          }
          // Default: lastWriteWins (proceed with upsert)
        }
      }

      final result = await _backendAdapter.send(operation);

      if (result.success) {
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
      } else {
        throw Exception(result.error ?? 'Unknown backend error');
      }
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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
