import 'dart:async';
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

  final _localChanges = StreamController<void>.broadcast();

  void _notifyChange() {
    _localChanges.add(null);
  }

  Stream<List<Map<String, dynamic>>> watchCustomers(String businessId) {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? localSub;
    StreamSubscription? cloudSub;

    void emit() async {
      try {
        final data = await getCustomers(businessId);
        if (!controller.isClosed) controller.add(data);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        emit();
        localSub = _localChanges.stream.listen((_) => emit());
        cloudSub = CloudSyncService.instance.watchCustomers(businessId).listen(
          (_) => emit(),
          onError: (e) {
            debugPrint('[CustomerRepository] Cloud watch failure: $e');
          },
        );
      },
      onCancel: () {
        localSub?.cancel();
        cloudSub?.cancel();
      },
    );

    return controller.stream;
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
    _notifyChange();
  }

  Future<void> deleteCustomer(String businessId, String id) async {
    await DBHelper.deleteCustomer(businessId, id);

    await SyncQueueService.instance.enqueue(
      entityName: 'customers',
      entityId: id,
      type: SyncOperationType.delete,
      payload: {'id': id, 'businessId': businessId},
    );
    _notifyChange();
  }

  Future<Map<String, dynamic>> getCustomerStatement(String businessId, String customerId) {
    return DBHelper.getCustomerStatement(customerId, businessId);
  }
}
