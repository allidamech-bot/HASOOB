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
    final tempDir = await Directory.systemTemp.createTemp('sync_consistency_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    fakeSyncService = FakeSyncService();
    syncEngine = SyncEngine(syncService: fakeSyncService, isTestMode: true);
    
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
        conflictStrategy TEXT,
        remoteVersion INTEGER,
        localVersion INTEGER,
        conflictReason TEXT
      )
    ''');
    
    final repository = SyncQueueRepository();
    await repository.clearAll();
  });

  group('Sync Consistency & Conflict Resolution', () {
    test('lastWriteWins ignores remote version and proceeds', () async {
      fakeSyncService.remoteVersions['products:p1'] = 10;
      
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.update,
        payload: {'name': 'New Name'},
        conflictStrategy: SyncConflictStrategy.lastWriteWins,
        remoteVersion: 5, // Local base version is older than remote
      );

      await syncEngine.processQueue();

      final allOps = await SyncQueueService.instance.getAll();
      expect(allOps.first.status, SyncStatus.synced);
      expect(fakeSyncService.upsertCounts['products'], 1);
    });

    test('manualReview strategy stops on conflict', () async {
      fakeSyncService.remoteVersions['products:p1'] = 10;
      
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.update,
        payload: {'name': 'New Name'},
        conflictStrategy: SyncConflictStrategy.manualReview,
        remoteVersion: 5, // Conflict: 10 > 5
      );

      await syncEngine.processQueue();

      final allOps = await SyncQueueService.instance.getAll();
      final op = allOps.first;
      expect(op.status, SyncStatus.conflict);
      expect(op.remoteVersion, 10);
      expect(op.conflictReason, contains('Remote version (10) is newer'));
      expect(fakeSyncService.upsertCounts['products'] ?? 0, 0);
    });

    test('resolveConflict with useRemote deletes the operation', () async {
      fakeSyncService.remoteVersions['products:p1'] = 10;
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.update,
        payload: {'name': 'New Name'},
        conflictStrategy: SyncConflictStrategy.manualReview,
        remoteVersion: 5,
      );

      await syncEngine.processQueue();
      var allOps = await SyncQueueService.instance.getAll();
      expect(allOps.length, 1);

      await SyncQueueService.instance.resolveConflictUseRemote(allOps.first.id);
      
      allOps = await SyncQueueService.instance.getAll();
      expect(allOps.isEmpty, true);
    });

    test('resolveConflict with local force updates the base version and retries', () async {
      fakeSyncService.remoteVersions['products:p1'] = 10;
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.update,
        payload: {'name': 'New Name'},
        conflictStrategy: SyncConflictStrategy.manualReview,
        remoteVersion: 5,
      );

      // 1. Detect conflict
      await syncEngine.processQueue();
      var allOps = await SyncQueueService.instance.getAll();
      var op = allOps.first;
      expect(op.status, SyncStatus.conflict);
      expect(op.remoteVersion, 10);

      // 2. Resolve by choosing local (force)
      await SyncQueueService.instance.resolveConflictUseLocal(op.id);
      
      allOps = await SyncQueueService.instance.getAll();
      op = allOps.first;
      expect(op.status, SyncStatus.pending);
      expect(op.remoteVersion, 10); // Base version updated to match remote

      // 3. Process again - should succeed now
      await syncEngine.processQueue();
      
      allOps = await SyncQueueService.instance.getAll();
      expect(allOps.first.status, SyncStatus.synced);
      expect(fakeSyncService.upsertCounts['products'], 1);
    });
  });
}
