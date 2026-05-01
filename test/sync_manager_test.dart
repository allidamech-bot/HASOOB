import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DBHelper.database();
    await db.delete('sync_operations');
  });

  test('SyncManager.runSync should process pending operations', () async {
    // 1. Enqueue an operation
    await SyncQueueService.instance.enqueue(
      entityName: 'test_entity',
      entityId: '123',
      type: SyncOperationType.create,
      payload: {'data': 'test'},
    );

    var pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 1);
    expect(pending.first.status, SyncStatus.pending);

    // 2. Call runSync
    await SyncManager.instance.runSync();

    // 3. Verify operation is no longer pending (it becomes synced)
    pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 0);
    
    // Check database directly to see if it is synced
    final db = await DBHelper.database();
    final results = await db.query('sync_operations');
    expect(results.length, 1);
    expect(results.first['status'], SyncStatus.synced.name);
  });
}
