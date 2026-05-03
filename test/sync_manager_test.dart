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
    final tempDir = await Directory.systemTemp.createTemp('sync_manager_test_');
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = await DBHelper.database();
    await db.execute('CREATE TABLE IF NOT EXISTS sync_operations(id TEXT PRIMARY KEY, entityName TEXT, entityId TEXT, type TEXT, payload TEXT, status TEXT, createdAt TEXT, updatedAt TEXT, attemptCount INTEGER, lastError TEXT)');
    await db.delete('sync_operations');

    fakeSyncService = FakeSyncService();
    final engine = SyncEngine(syncService: fakeSyncService);
    SyncManager.instance.setEngine(engine);
  });

  test('SyncManager.runSync should process pending operations', () async {
    // 1. Enqueue an operation
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: '123',
      type: SyncOperationType.create,
      payload: {'id': '123', 'name': 'test'},
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
    expect(fakeSyncService.callCount, 1);
  });
}
