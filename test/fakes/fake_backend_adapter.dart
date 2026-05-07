import 'package:hasoob_app/data/services/backend_adapter.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';

class FakeBackendAdapter implements BackendAdapter {
  final List<SyncOperation> sentOperations = [];
  final Map<String, Map<String, dynamic>> remoteData = {};
  bool shouldFail = false;
  String? failureError;

  @override
  Future<BackendResult> send(SyncOperation operation) async {
    if (shouldFail) {
      return BackendResult.failure(failureError ?? 'Fake error');
    }
    sentOperations.add(operation);
    return BackendResult.success();
  }

  @override
  Future<Map<String, dynamic>?> fetchRemoteData(String entityName, String entityId) async {
    return remoteData['$entityName:$entityId'];
  }

  void setRemoteData(String entityName, String entityId, Map<String, dynamic> data) {
    remoteData['$entityName:$entityId'] = data;
  }
}
