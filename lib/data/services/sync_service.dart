import 'dart:async';

abstract class SyncService {
  Future<void> upsert(String entityName, Map<String, dynamic> data);
  Future<void> delete(String entityName, String id);
  Future<int?> getRemoteVersion(String entityName, String id);
  Future<Map<String, dynamic>?> getRemoteData(String entityName, String id);
}
