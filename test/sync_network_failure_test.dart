import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_sync_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeSyncService fakeSyncService;
  late SyncEngine syncEngine;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sync_network_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    fakeSyncService = FakeSyncService();
    syncEngine = SyncEngine(syncService: fakeSyncService);
    
    final db = await DBHelper.database();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${SyncQueueRepository.tableName}(
        id TEXT PRIMARY KEY,
        entityName TEXT,
        entityId TEXT,
        type TEXT,
        payload TEXT,
        status TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        attemptCount INTEGER,
        lastError TEXT
      )
    ''');
    
    final repository = SyncQueueRepository();
    await repository.clearAll();
  });

  tearDown(() async {
    final db = await DBHelper.database();
    await db.close();
  });

  group('SyncEngine Network Failure Simulations', () {
    test('Operation is retried after a transient failure', () async {
      final repository = SyncQueueRepository();
      
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.create,
        payload: {'id': 'p1', 'name': 'Test Product'},
      );

      // Simulate transient failure (e.g., SocketException)
      fakeSyncService.shouldFail = true;
      await syncEngine.processQueue();

      var ops = await repository.getAllOperations();
      expect(ops.first.status, SyncStatus.failed);
      expect(ops.first.attemptCount, 1);

      // Restore "network" and process again
      fakeSyncService.shouldFail = false;
      await syncEngine.processQueue();

      // Wait a bit if there's any async gap, though engine is sequential
      ops = await repository.getAllOperations();
      expect(ops.first.status, SyncStatus.synced);
      expect(ops.first.attemptCount, 1); // attemptCount was 1 when it started the second run
    });

    test('Queue processing continues after one operation fails', () async {
      final repository = SyncQueueRepository();
      
      // Op 1: Will fail
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-fail',
        type: SyncOperationType.create,
        payload: {'id': 'p-fail', 'name': 'Failing Product'},
      );

      // Op 2: Will succeed
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-success',
        type: SyncOperationType.create,
        payload: {'id': 'p-success', 'name': 'Successful Product'},
      );

      await syncEngine.processQueue();

      final ops = await repository.getAllOperations();
      final failOp = ops.firstWhere((o) => o.entityId == 'p-fail');
      final successOp = ops.firstWhere((o) => o.entityId == 'p-success');

      expect(failOp.status, SyncStatus.failed);
      expect(successOp.status, SyncStatus.synced);
    });
  });
}
