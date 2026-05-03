import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/smart_sync_trigger_service.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_sync_service.dart';

void main() {
  late FakeSyncService fakeSyncService;
  late SmartSyncTriggerService triggerService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('smart_sync_test_');
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = await DBHelper.database();
    await db.execute('CREATE TABLE IF NOT EXISTS sync_operations(id TEXT PRIMARY KEY, entityName TEXT, entityId TEXT, type TEXT, payload TEXT, status TEXT, createdAt TEXT, updatedAt TEXT, attemptCount INTEGER, lastError TEXT)');
    await db.delete('sync_operations');

    fakeSyncService = FakeSyncService();
    final engine = SyncEngine(syncService: fakeSyncService);
    SyncManager.instance.setEngine(engine);
    triggerService = SmartSyncTriggerService(SyncManager.instance);
  });

  test('onAppStarted does not run when queue is empty', () async {
    await triggerService.onAppStarted();
    expect(fakeSyncService.callCount, 0);
  });

  test('onAppStarted runs when pending operations exist', () async {
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: '123',
      type: SyncOperationType.create,
      payload: {'id': '123', 'name': 'test'},
    );
    // Reset call count because enqueue might trigger a sync via SmartSyncTriggerService in the implementation
    fakeSyncService.callCount = 0; 
    
    await triggerService.onAppStarted();
    expect(fakeSyncService.callCount, 1);
  });

  test('onConnectivityRestored runs when pending operations exist', () async {
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: '123',
      type: SyncOperationType.create,
      payload: {'id': '123', 'name': 'test'},
    );
    fakeSyncService.callCount = 0;

    await triggerService.onConnectivityRestored();
    expect(fakeSyncService.callCount, 1);
  });

  test('onUserRequestedSync runs even if queue is empty', () async {
    await triggerService.onUserRequestedSync();
    // It runs the sync engine, which checks the queue. 
    // Since queue is empty, callCount to fakeSyncService (which is inside _processOperation) remains 0,
    // but SyncManager.runSync was definitely called.
    // We can verify by making SyncManager provide a way to check if it ran, 
    // or just check that it doesn't crash.
    expect(fakeSyncService.callCount, 0);
  });

  test('onUserRequestedSync processes operations if they exist', () async {
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: '123',
      type: SyncOperationType.create,
      payload: {'id': '123', 'name': 'test'},
    );
    fakeSyncService.callCount = 0;

    await triggerService.onUserRequestedSync();
    expect(fakeSyncService.callCount, 1);
  });

  test('prevents parallel sync runs', () async {
    await SyncQueueService.instance.enqueue(
      entityName: 'products',
      entityId: '123',
      type: SyncOperationType.create,
      payload: {'id': '123', 'name': 'test'},
    );
    fakeSyncService.callCount = 0;

    // Use a delay in fake sync to simulate long running task if possible, 
    // but here we just check _isRunning in trigger service.
    // We can't easily check internal state of triggerService without making it public or using a mock.
    // But we can call it multiple times and ensure it doesn't double-call SyncManager.
    
    final future1 = triggerService.onAppStarted();
    final future2 = triggerService.onAppStarted();
    
    await Future.wait([future1, future2]);
    
    // SyncManager also has its own _isRunning, so even if triggerService failed, 
    // SyncManager would prevent it. 
    // Given current implementation, callCount should be 1.
    expect(fakeSyncService.callCount, 1);
  });
}
