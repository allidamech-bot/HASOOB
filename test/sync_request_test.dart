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
    // Ensure flag is reset
    if (SyncManager.instance.syncRequested) {
      await SyncManager.instance.runSync();
    }
  });

  test('Enqueuing should set syncRequested flag but NOT run sync', () async {
    expect(SyncManager.instance.syncRequested, false);

    // 1. Enqueue
    await SyncQueueService.instance.enqueue(
      entityName: 'test_request',
      entityId: 'req_1',
      type: SyncOperationType.create,
      payload: {'data': 'val'},
    );

    // 2. Check flag
    expect(SyncManager.instance.syncRequested, true, reason: 'Flag should be set after enqueue');

    // 3. Check status (should still be pending)
    final pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 1);
    expect(pending.first.status, SyncStatus.pending, reason: 'Operation should still be pending');
  });

  test('runSync should clear syncRequested flag', () async {
    SyncManager.instance.requestSync();
    expect(SyncManager.instance.syncRequested, true);

    await SyncManager.instance.runSync();

    expect(SyncManager.instance.syncRequested, false, reason: 'Flag should be cleared after runSync');
  });
}
