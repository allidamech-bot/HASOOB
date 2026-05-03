import 'package:hasoob_app/data/services/sync_service.dart';

class FakeSyncService implements SyncService {
  bool shouldFail = false;
  int callCount = 0;

  @override
  Future<void> upsertProduct(Map<String, dynamic> data) async {
    callCount++;
    if (shouldFail || (data['id'] != null && data['id'].toString().contains('fail'))) {
      throw Exception('simulated failure');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    callCount++;
    if (shouldFail || id.contains('fail')) {
      throw Exception('simulated failure');
    }
  }

  @override
  Future<void> upsertCustomer(Map<String, dynamic> data) async {
    callCount++;
    if (shouldFail || (data['id'] != null && data['id'].toString().contains('fail'))) {
      throw Exception('simulated failure');
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    callCount++;
    if (shouldFail || id.contains('fail')) {
      throw Exception('simulated failure');
    }
  }
}
