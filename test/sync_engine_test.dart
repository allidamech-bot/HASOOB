import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_backend_adapter.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeBackendAdapter fakeBackend;
  late SyncEngine syncEngine;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sync_engine_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    fakeBackend = FakeBackendAdapter();
    syncEngine = SyncEngine(backendAdapter: fakeBackend, isTestMode: true);
    
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
        lastError TEXT,
        priority INTEGER DEFAULT 2,
        retryDelaySeconds INTEGER DEFAULT 0
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

  group('SyncEngine Adapter Boundery Tests', () {
    test('processing pending operation marks it synced', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.create,
        payload: {'name': 'Product 1'},
      );

      await syncEngine.processQueue();

      final db = await DBHelper.database();
      final results = await db.query(SyncQueueRepository.tableName);
      expect(results.length, 1);
      expect(results.first['status'], SyncStatus.synced.name);
      expect(fakeBackend.sentOperations.length, 1);
    });

    test('simulated failed operation marks it failed and increments attempt count', () async {
      fakeBackend.shouldFail = true;
      fakeBackend.failureError = 'Network timeout';

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-fail',
        type: SyncOperationType.create,
        payload: {'id': 'p-fail', 'name': 'Product Fail'},
      );

      await syncEngine.processQueue();

      final db = await DBHelper.database();
      final results = await db.query(SyncQueueRepository.tableName);
      expect(results.length, 1);
      expect(results.first['status'], SyncStatus.failed.name);
      expect(results.first['attemptCount'], 1);
      expect(results.first['lastError'], contains('Network timeout'));
    });

    test('retry failed operation respects max retry count', () async {
      const entityId = 'p-fail-retry';
      fakeBackend.shouldFail = true;

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: entityId,
        type: SyncOperationType.create,
        payload: {'id': entityId, 'name': 'Retry Test'},
      );

      // Attempt 1 (fails, count -> 1)
      await syncEngine.processQueue();
      
      // Attempt 2 (fails, count -> 2)
      await _manualResetToPending(entityId);
      await syncEngine.processQueue();
      
      // Attempt 3 (fails, count -> 3)
      await _manualResetToPending(entityId);
      await syncEngine.processQueue();

      final db = await DBHelper.database();
      var results = await db.query(
        SyncQueueRepository.tableName,
        where: 'entityId = ?',
        whereArgs: [entityId],
      );
      expect(results.first['attemptCount'], 3);
      expect(results.first['status'], SyncStatus.failed.name);

      // Attempt 4: Should be skipped because count == 3
      await _manualResetToPending(entityId);
      await syncEngine.processQueue();

      results = await db.query(
        SyncQueueRepository.tableName,
        where: 'entityId = ?',
        whereArgs: [entityId],
      );
      expect(results.first['attemptCount'], 3); 
      expect(results.first['status'], SyncStatus.pending.name); 
    });

    test('conflict detection skips operation when remote is newer', () async {
      const entityId = 'p-conflict';
      fakeBackend.setRemoteData('products', entityId, {
        'remoteVersion': 10,
        'name': 'Newer Remote Name',
      });

      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: entityId,
        type: SyncOperationType.update,
        payload: {'id': entityId, 'name': 'Local Update'},
        conflictStrategy: SyncConflictStrategy.manualReview,
        remoteVersion: 5, // Local base is 5, remote is 10 -> conflict!
      );

      await syncEngine.processQueue();

      final db = await DBHelper.database();
      final results = await db.query(SyncQueueRepository.tableName);
      expect(results.first['status'], SyncStatus.conflict.name);
      expect(fakeBackend.sentOperations.isEmpty, true);
    });
  });
}

/// Helper to reset an operation to pending for retry testing.
Future<void> _manualResetToPending(String entityId) async {
  final db = await DBHelper.database();
  final results = await db.query(
    SyncQueueRepository.tableName,
    where: 'entityId = ?',
    whereArgs: [entityId],
  );
  if (results.isNotEmpty) {
    final map = Map<String, dynamic>.from(results.first);
    // Payload needs to be decoded because SyncOperation.fromMap expects a Map, 
    // but DB stores it as a JSON string.
    map['payload'] = jsonDecode(map['payload'] as String);
    final operation = SyncOperation.fromMap(map);
    await SyncQueueService.instance.updateStatus(operation, SyncStatus.pending);
  }
}
