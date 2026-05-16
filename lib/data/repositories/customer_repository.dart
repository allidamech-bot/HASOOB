import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../backend/backend_client.dart';
import '../backend/backend_client_factory.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';

class CustomerRepository {
  final BackendClient backendClient;

  CustomerRepository({BackendClient? backendClient})
      : backendClient = backendClient ?? BackendClientFactory.create();

  Stream<List<Map<String, dynamic>>> watchCustomers(String businessId) async* {
    // 1. Yield local data immediately
    final localData = await getCustomers(businessId);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    try {
      final cloudStream = CloudSyncService.instance.watchCustomers(businessId);
      await for (final _ in cloudStream) {
        final refreshedData = await getCustomers(businessId);
        yield refreshedData;
      }
    } catch (e) {
      debugPrint('[CustomerRepository] watchCustomers cloud failure: $e. Using local data.');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers(String businessId) {
    return DBHelper.getCustomers(businessId);
  }

  Future<void> saveCustomer(String businessId, Map<String, dynamic> data) async {
    final isUpdate = data['id'] != null;
    final id = data['id']?.toString() ?? 'CUS_${DateTime.now().microsecondsSinceEpoch}';
    final payload = {
      ...data,
      'id': id,
      'businessId': businessId,
    };

    await DBHelper.saveCustomer(payload);

    await SyncQueueService.instance.enqueue(
      entityName: 'customers',
      entityId: id,
      type: isUpdate ? SyncOperationType.update : SyncOperationType.create,
      payload: payload,
    );
  }

  Future<void> deleteCustomer(String businessId, String id) async {
    final db = await DBHelper.database();
    await db.delete(
      'customers',
      where: 'businessId = ? AND id = ?',
      whereArgs: [businessId, id],
    );

    await SyncQueueService.instance.enqueue(
      entityName: 'customers',
      entityId: id,
      type: SyncOperationType.delete,
      payload: {'id': id, 'businessId': businessId},
    );
  }

  Future<Map<String, dynamic>> getCustomerStatement(String businessId, String customerId) {
    return DBHelper.getCustomerStatement(customerId, businessId);
  }
}
