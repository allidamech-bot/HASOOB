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
    // Reset flags
    if (SyncManager.instance.syncRequested) {
      await SyncManager.instance.runSync();
    }
  });

  test('runIfRequested does nothing when syncRequested is false', () async {
    // 1. Enqueue without triggering anything that sets syncRequested to true
    // (Actually enqueue sets it to true, so we reset it)
    await SyncQueueService.instance.enqueue(
      entityName: 'test',
      entityId: '1',
      type: SyncOperationType.create,
      payload: {},
    );
    
    // Manually reset flag to simulate no request
    await SyncManager.instance.runSync(); 
    expect(SyncManager.instance.syncRequested, false);

    // 2. Add another pending operation without requesting sync (simulated)
    final db = await DBHelper.database();
    await db.insert('sync_operations', {
      'id': 'manual_1',
      'entity_name': 'test',
      'entity_id': '2',
      'operation_type': SyncOperationType.create.name,
      'payload': '{}',
      'status': SyncStatus.pending.name,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 3. runIfRequested
    await SyncManager.instance.runIfRequested();

    // 4. Verify it's still pending
    final pending = await SyncQueueService.instance.getPending();
    expect(pending.any((o) => o.id == 'manual_1'), true);
  });

  test('requestSync then runIfRequested processes queue', () async {
    // 1. Enqueue (sets syncRequested = true)
    await SyncQueueService.instance.enqueue(
      entityName: 'test_exec',
      entityId: 'exec_1',
      type: SyncOperationType.create,
      payload: {'data': 'val'},
    );
    expect(SyncManager.instance.syncRequested, true);

    // 2. runIfRequested
    await SyncManager.instance.runIfRequested();

    // 3. Verify processed
    expect(SyncManager.instance.syncRequested, false);
    final pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 0);
  });
}
