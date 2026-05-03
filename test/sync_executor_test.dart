import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_sync_service.dart';

void main() {
  late FakeSyncService fakeSyncService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('sync_executor_test_');
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = await DBHelper.database();
    await db.execute('CREATE TABLE IF NOT EXISTS sync_operations(id TEXT PRIMARY KEY, entityName TEXT, entityId TEXT, type TEXT, payload TEXT, status TEXT, createdAt TEXT, updatedAt TEXT, attemptCount INTEGER, lastError TEXT)');
    await db.delete('sync_operations');

    fakeSyncService = FakeSyncService();
    final engine = SyncEngine(syncService: fakeSyncService);
    SyncManager.instance.setEngine(engine);

    // Reset flags
    if (SyncManager.instance.syncRequested) {
      await SyncManager.instance.runSync();
    }
  });

  test('runIfRequested does nothing when syncRequested is false', () async {
    // 1. Enqueue without triggering anything that sets syncRequested to true
    // (Actually enqueue sets it to true, so we reset it)
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: '1',
      type: SyncOperationType.create,
      payload: {'id': '1'},
    );
    
    // Manually reset flag to simulate no request
    await SyncManager.instance.runSync(); 
    expect(SyncManager.instance.syncRequested, false);

    // 2. Add another pending operation without requesting sync (simulated)
    final db = await DBHelper.database();
    await db.insert('sync_operations', {
      'id': 'manual_1',
      'entityName': 'products',
      'entityId': '2',
      'type': 'create',
      'payload': '{"id": "2"}',
      'status': SyncStatus.pending.name,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'attemptCount': 0,
    });

    // 3. runIfRequested
    await SyncManager.instance.runIfRequested();

    // 4. Verify it's still pending
    final pending = await SyncQueueService.instance.getPending();
    expect(pending.any((o) => o.id == 'manual_1'), true);
    // Should NOT have called service
    expect(fakeSyncService.callCount, 1); // Only for the first enqueue that was synced in step 1
  });

  test('requestSync then runIfRequested processes queue', () async {
    // 1. Enqueue (sets syncRequested = true)
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: 'exec_1',
      type: SyncOperationType.create,
      payload: {'id': 'exec_1', 'data': 'val'},
    );
    expect(SyncManager.instance.syncRequested, true);

    // 2. runIfRequested
    await SyncManager.instance.runIfRequested();

    // 3. Verify processed
    expect(SyncManager.instance.syncRequested, false);
    final pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 0);
    expect(fakeSyncService.callCount, 1);
  });
}
