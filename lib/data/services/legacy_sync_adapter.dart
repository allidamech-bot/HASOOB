import 'backend_adapter.dart';
import 'sync_service.dart';
import '../models/sync_operation.dart';

class LegacySyncAdapter implements BackendAdapter {
  final SyncService _syncService;

  LegacySyncAdapter(this._syncService);

  @override
  Future<BackendResult> send(SyncOperation operation) async {
    try {
      if (operation.type == SyncOperationType.delete) {
        await _syncService.delete(operation.entityName, operation.entityId);
      } else {
        await _syncService.upsert(operation.entityName, operation.payload);
      }
      return BackendResult.success();
    } catch (e) {
      return BackendResult.failure(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchRemoteData(String entityName, String entityId) async {
    return await _syncService.getRemoteData(entityName, entityId);
  }
}
