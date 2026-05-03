import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/smart_sync_trigger_service.dart';
import 'package:hasoob_app/data/services/analytics_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeSyncService fakeSyncService;
  late SyncEngine syncEngine;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sync_network_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
    
    // Initialize SmartSyncTriggerService dependency
    SmartSyncTriggerService(SyncManager.instance).initialize();
  });

  setUp(() async {
    fakeSyncService = FakeSyncService();
    syncEngine = SyncEngine(
      syncService: fakeSyncService,
      analytics: NoOpAnalyticsService(),
    );
    SyncManager.instance.setEngine(syncEngine);
    
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

      // Restoration of "network" happens, but because we are processing twice, 
      // let's ensure we are not hitting race conditions with async loops.
      fakeSyncService.shouldFail = false;
      await syncEngine.processQueue();

      ops = await repository.getAllOperations();
      expect(ops.first.status, SyncStatus.synced);
      expect(ops.first.attemptCount, 1);
    });

    test('Queue processing continues after one operation fails', () async {
      final repository = SyncQueueRepository();
      
      // Op 1: Will fail due to ID containing 'fail'
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
      
      // We expect the one with 'fail' in ID to be FAILED
      final failOp = ops.firstWhere((o) => o.entityId == 'p-fail');
      // We expect the one without 'fail' in ID to be SYNCED
      final successOp = ops.firstWhere((o) => o.entityId == 'p-success');

      expect(failOp.status, SyncStatus.failed);
      expect(successOp.status, SyncStatus.synced);
    });
  });
}
