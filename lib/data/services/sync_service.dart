import 'dart:async';

abstract class SyncService {
  Future<void> upsertProduct(Map<String, dynamic> data);
  Future<void> deleteProduct(String id);
  Future<void> upsertCustomer(Map<String, dynamic> data);
  Future<void> deleteCustomer(String id);
  
  // Add other methods as they are needed by SyncEngine
}
