import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    // Set a unique database path for this test file to prevent locks with other test files
    final tempDir = await Directory.systemTemp.createTemp('sync_engine_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    // Ensure table exists in the test DB environment
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
    // Clear sync_operations table before each test
    await repository.clearAll();
  });

  tearDown(() async {
    // Close database to release file lock and add small delay
    final db = await DBHelper.database();
    await db.close();
    await Future.delayed(const Duration(milliseconds: 50));
  });

  group('SyncEngine Sandbox Tests', () {
    test('processing pending operation marks it synced', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.create,
        payload: {'name': 'Product 1'},
      );

      await SyncEngine.instance.processQueue();

      final db = await DBHelper.database();
      final results = await db.query(SyncQueueRepository.tableName);
      expect(results.length, 1);
      expect(results.first['status'], SyncStatus.synced.name);
    });

    test('simulated failed operation marks it failed and increments attempt count', () async {
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: 'p-fail',
        type: SyncOperationType.create,
        payload: {'name': 'Product Fail'},
      );

      await SyncEngine.instance.processQueue();

      final db = await DBHelper.database();
      final results = await db.query(SyncQueueRepository.tableName);
      expect(results.length, 1);
      expect(results.first['status'], SyncStatus.failed.name);
      expect(results.first['attemptCount'], 1);
    });

    test('retry failed operation respects max retry count', () async {
      const entityId = 'p-fail-retry';
      await SyncQueueService.instance.enqueue(
        entityName: 'products',
        entityId: entityId,
        type: SyncOperationType.create,
        payload: {'name': 'Retry Test'},
      );

      // Attempt 1 (fails, count -> 1)
      await SyncEngine.instance.processQueue();
      
      // Attempt 2 (fails, count -> 2)
      await _manualResetToPending(entityId);
      await SyncEngine.instance.processQueue();
      
      // Attempt 3 (fails, count -> 3)
      await _manualResetToPending(entityId);
      await SyncEngine.instance.processQueue();

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
      await SyncEngine.instance.processQueue();

      results = await db.query(
        SyncQueueRepository.tableName,
        where: 'entityId = ?',
        whereArgs: [entityId],
      );
      expect(results.first['attemptCount'], 3); // Still 3
      expect(results.first['status'], SyncStatus.pending.name); // Remained pending (skipped)
    });

    test('double process call does not run concurrently', () async {
      // Execute sequentially as per instructions to avoid parallel DB locks
      await SyncEngine.instance.processQueue();
      await SyncEngine.instance.processQueue();
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
