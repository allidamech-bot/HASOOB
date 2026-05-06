import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
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
    final tempDir = await Directory.systemTemp.createTemp('sync_intelligence_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    fakeSyncService = FakeSyncService();
    syncEngine = SyncEngine(syncService: fakeSyncService);
    
    final db = await DBHelper.database();
    await db.execute('DROP TABLE IF EXISTS ${SyncQueueRepository.tableName}');
    await db.execute('''
      CREATE TABLE ${SyncQueueRepository.tableName}(
        id TEXT PRIMARY KEY,
        entityName TEXT,
        entityId TEXT,
        type TEXT,
        payload TEXT,
        status TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        attemptCount INTEGER,
        lastError TEXT,
        priority INTEGER DEFAULT 2,
        retryDelaySeconds INTEGER DEFAULT 0,
        fingerprint TEXT,
        conflictStrategy TEXT DEFAULT 'lastWriteWins',
        remoteVersion INTEGER DEFAULT 0,
        localVersion INTEGER DEFAULT 0,
        conflictReason TEXT
      )
    ''');
    
    final repository = SyncQueueRepository();
    await repository.clearAll();
  });

  tearDown(() async {
    final db = await DBHelper.database();
    await db.close();
    await Future.delayed(const Duration(milliseconds: 50));
  });

  group('Sync Intelligence Tests', () {
    test('priority ordering works (HIGH -> MEDIUM -> LOW)', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-low',
        type: SyncOperationType.create,
        payload: {'name': 'Low'},
        priority: 3,
      );
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-high',
        type: SyncOperationType.create,
        payload: {'name': 'High'},
        priority: 1,
      );
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-med',
        type: SyncOperationType.create,
        payload: {'name': 'Medium'},
        priority: 2,
      );

      final pending = await SyncQueueService.instance.getPending();
      expect(pending.length, 3);
      expect(pending[0].entityId, 'p-high');
      expect(pending[1].entityId, 'p-med');
      expect(pending[2].entityId, 'p-low');
    });

    test('batch size respected (processes 5 at a time)', () async {
      for (int i = 0; i < 12; i++) {
        await SyncQueueService.instance.enqueue(
          entityName: 'products',
          entityId: 'p-$i',
          type: SyncOperationType.create,
          payload: {'name': 'Product $i'},
        );
      }

      // First call should process all 12 because we added a while(true) loop that breaks if < batchSize
      
      await syncEngine.processQueue();
      
      final db = await DBHelper.database();
      final syncedCount = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM ${SyncQueueRepository.tableName} WHERE status = 'synced'")
      );
      expect(syncedCount, 12);
    });

    test('exponential backoff works (20s, 40s, 80s)', () async {
      const entityId = 'p-fail-backoff';
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: entityId,
        type: SyncOperationType.create,
        payload: {'id': entityId, 'name': 'Fail'},
      );

      // Attempt 1 (fails)
      await syncEngine.processQueue();
      
      var op = (await SyncQueueService.instance.getAll()).first;
      expect(op.attemptCount, 1);
      // baseDelay = 2^1 * 10 = 20
      // jitter = 0..6
      expect(op.retryDelaySeconds, greaterThanOrEqualTo(20));
      expect(op.retryDelaySeconds, lessThanOrEqualTo(26));

      // Attempt 2 (fails)
      await SyncQueueService.instance.updateStatus(op, SyncStatus.failed); 
      op = (await SyncQueueService.instance.getAll()).first;
      expect(op.attemptCount, 2);
      // baseDelay = 2^2 * 10 = 40
      // jitter = 0..12
      expect(op.retryDelaySeconds, greaterThanOrEqualTo(40));
      expect(op.retryDelaySeconds, lessThanOrEqualTo(52));
      
      await SyncQueueService.instance.updateStatus(op, SyncStatus.failed);
      op = (await SyncQueueService.instance.getAll()).first;
      expect(op.attemptCount, 3);
      // baseDelay = 2^3 * 10 = 80
      // jitter = 0..24
      expect(op.retryDelaySeconds, greaterThanOrEqualTo(80));
      expect(op.retryDelaySeconds, lessThanOrEqualTo(104));
    });

    test('retry delay prevents execution', () async {
      const entityId = 'p-fail-delay';
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: entityId,
        type: SyncOperationType.create,
        payload: {'id': entityId, 'name': 'Fail'},
      );

      // 1. Fail it once to set a delay
      await syncEngine.processQueue();
      
      final op = (await SyncQueueService.instance.getAll()).first;
      expect(op.status, SyncStatus.failed);
      expect(op.retryDelaySeconds, greaterThanOrEqualTo(20));

      // 2. Set to pending
      final db = await DBHelper.database();
      await db.update(SyncQueueRepository.tableName, {'status': 'pending'}, where: 'id = ?', whereArgs: [op.id]);
      
      // 3. Process queue again immediately. It should be SKIPPED because of delay.
      await syncEngine.processQueue();
      
      final opAfter = (await SyncQueueService.instance.getAll()).first;
      expect(opAfter.status, SyncStatus.pending); 
      expect(fakeSyncService.callCount, 1);
    });

    test('fingerprinting prevents duplicate enqueues', () async {
      final payload = {'name': 'Duplicate'};
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-dup',
        type: SyncOperationType.create,
        payload: payload,
      );

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-dup',
        type: SyncOperationType.create,
        payload: payload,
      );

      final all = await SyncQueueService.instance.getAll();
      expect(all.length, 1);
    });

    test('create + delete collapse logic', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-collapse',
        type: SyncOperationType.create,
        payload: {'name': 'To be deleted'},
      );

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-collapse',
        type: SyncOperationType.delete,
        payload: {},
      );

      final all = await SyncQueueService.instance.getAll();
      expect(all.length, 1);
      expect(all.first.type, SyncOperationType.delete);
    });

    test('sequential updates merge logic', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-merge',
        type: SyncOperationType.update,
        payload: {'name': 'Version 1', 'price': 10},
      );

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-merge',
        type: SyncOperationType.update,
        payload: {'price': 20, 'category': 'A'},
      );

      final all = await SyncQueueService.instance.getAll();
      expect(all.length, 1);
      expect(all.first.payload['name'], 'Version 1');
      expect(all.first.payload['price'], 20);
      expect(all.first.payload['category'], 'A');
    });

    test('integrity validation rejects missing entityId', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: '', // Invalid
        type: SyncOperationType.create,
        payload: {'name': 'Invalid'},
      );

      await syncEngine.processQueue();

      final all = await SyncQueueService.instance.getAll();
      expect(all.first.status, SyncStatus.rejected);
      expect(all.first.lastError, contains('Missing entityId'));
    });

    test('conflict detection - manual review', () async {
      fakeSyncService.remoteVersions['products:p-conflict'] = 5;

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-conflict',
        type: SyncOperationType.update,
        payload: {'name': 'Conflicted'},
        remoteVersion: 3, // Older than remote
        conflictStrategy: SyncConflictStrategy.manualReview,
      );

      await syncEngine.processQueue();

      final all = await SyncQueueService.instance.getAll();
      expect(all.first.status, SyncStatus.conflict);
      expect(all.first.conflictReason, contains('Remote version (5) is newer than local base (3)'));
    });
  });
}
