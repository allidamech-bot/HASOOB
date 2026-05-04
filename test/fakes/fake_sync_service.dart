import 'package:hasoob_app/data/services/sync_service.dart';

class FakeSyncService implements SyncService {
  bool shouldFail = false;
  int callCount = 0;
  
  Map<String, int> upsertCounts = {};
  Map<String, int> deleteCounts = {};

  @override
  Future<void> upsert(String entityName, Map<String, dynamic> data) async {
    callCount++;
    upsertCounts[entityName] = (upsertCounts[entityName] ?? 0) + 1;
    
    if (shouldFail || (data['id'] != null && data['id'].toString().contains('fail'))) {
      throw Exception('simulated failure');
    }
  }

  @override
  Future<void> delete(String entityName, String id) async {
    callCount++;
    deleteCounts[entityName] = (deleteCounts[entityName] ?? 0) + 1;
    
    if (shouldFail || id.contains('fail')) {
      throw Exception('simulated failure');
    }
  }

  // Legacy helper flags for tests that were checking these specific ones
  bool get upsertProductCalled => (upsertCounts['products'] ?? 0) > 0;
  bool get deleteProductCalled => (deleteCounts['products'] ?? 0) > 0;
}
