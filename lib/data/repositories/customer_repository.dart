import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../backend/backend_client.dart';
import '../backend/backend_client_factory.dart';
import '../services/sync_queue_service.dart';
import '../models/sync_operation.dart';

class CustomerRepository {
  final BackendClient backendClient;

  CustomerRepository({BackendClient? backendClient})
      : backendClient = backendClient ?? BackendClientFactory.create();

  Stream<List<Map<String, dynamic>>> watchCustomers(String businessId) {
    return CloudSyncService.instance
        .watchCustomers(businessId)
        .asyncMap((_) => DBHelper.getCustomers(businessId));
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

    try {
      await DBHelper.saveCustomer(payload);
    } catch (_) {
      // Expected potential legacy Firebase sync failure; proceed to Sync Queue
    }

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
