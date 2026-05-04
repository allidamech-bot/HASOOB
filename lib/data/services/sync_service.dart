import 'dart:async';

abstract class SyncService {
  Future<void> upsert(String entityName, Map<String, dynamic> data);
  Future<void> delete(String entityName, String id);
}
