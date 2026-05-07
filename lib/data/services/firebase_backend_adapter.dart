import 'package:firebase_auth/firebase_auth.dart';
import 'backend_adapter.dart';
import '../models/sync_operation.dart';
import 'cloud_sync_service.dart';
import '../../core/business/business_context.dart';

class FirebaseBackendAdapter implements BackendAdapter {
  late final CloudSyncService _cloudSyncService = CloudSyncService.instance;
  
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<BackendResult> send(SyncOperation operation) async {
    final uid = _uid;
    if (uid == null) {
      return BackendResult.failure('User not authenticated');
    }

    try {
      final payload = _preparePayload(operation, uid);

      if (operation.type == SyncOperationType.delete) {
        await _cloudSyncService.delete(operation.entityName, operation.entityId);
      } else {
        await _cloudSyncService.upsert(operation.entityName, payload);
      }

      return BackendResult.success();
    } catch (e) {
      return BackendResult.failure(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchRemoteData(String entityName, String entityId) async {
    return await _cloudSyncService.getRemoteData(entityName, entityId);
  }

  Map<String, dynamic> _preparePayload(SyncOperation operation, String? uid) {
    final payload = Map<String, dynamic>.from(operation.payload);
    
    // Ensure critical fields are present
    payload['id'] = operation.entityId;
    payload['businessId'] = BusinessContext.resolveBusinessId(payload['businessId']);
    payload['ownerId'] = uid ?? 'anonymous';
    payload['updatedAt'] = operation.updatedAt.toIso8601String();
    payload['localVersion'] = operation.localVersion;
    payload['remoteVersion'] = operation.remoteVersion;
    
    // Add operation metadata if useful
    payload['_sync_metadata'] = {
      'operation_id': operation.id,
      'operation_type': operation.type.name,
      'device_id': 'unknown', // Placeholder as requested if no safe source exists
      'synced_at': DateTime.now().toIso8601String(),
    };

    return payload;
  }
}
