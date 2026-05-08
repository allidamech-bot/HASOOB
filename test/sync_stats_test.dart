import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SyncQueueRepository.getSyncStats', () {
    late SyncQueueRepository repository;

    setUp(() async {
      repository = SyncQueueRepository();
      await repository.clearAll();
    });

    test('should return correct stats for empty queue', () async {
      final stats = await repository.getSyncStats();
      expect(stats['pending'], 0);
      expect(stats['failed'], 0);
      expect(stats['conflicts'], 0);
      expect(stats['syncedToday'], 0);
      expect(stats['lastSyncTime'], isNull);
    });

    test('should return correct counts for different statuses', () async {
      final now = DateTime.now();
      
      await repository.enqueue(SyncOperation(
        id: '1',
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.create,
        payload: {},
        status: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.enqueue(SyncOperation(
        id: '2',
        entityName: 'products',
        entityId: 'p2',
        type: SyncOperationType.create,
        payload: {},
        status: SyncStatus.failed,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.enqueue(SyncOperation(
        id: '3',
        entityName: 'products',
        entityId: 'p3',
        type: SyncOperationType.create,
        payload: {},
        status: SyncStatus.conflict,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.enqueue(SyncOperation(
        id: '4',
        entityName: 'products',
        entityId: 'p4',
        type: SyncOperationType.create,
        payload: {},
        status: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
      ));

      final stats = await repository.getSyncStats();
      expect(stats['pending'], 1);
      expect(stats['failed'], 2); // failed + conflict
      expect(stats['conflicts'], 1);
      expect(stats['syncedToday'], 1);
      expect(stats['lastSyncTime'], isNotNull);
    });
  });
}
