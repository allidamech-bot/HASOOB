
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_sync_service.dart';
import 'fakes/fake_analytics_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SyncQueueRepository repository;
  late SyncQueueService service;

  setUp(() async {
    repository = SyncQueueRepository();
    service = SyncQueueService.instance;
    await repository.clearAll();
  });

  group('Priority and FIFO Ordering', () {
    test('Higher priority operations should be retrieved first', () async {
      await service.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.create,
        payload: {'name': 'Low Priority'},
        priority: 3,
      );
      await service.enqueue(
        entityName: 'products',
        entityId: 'p2',
        type: SyncOperationType.create,
        payload: {'name': 'High Priority'},
        priority: 1,
      );
      await service.enqueue(
        entityName: 'products',
        entityId: 'p3',
        type: SyncOperationType.create,
        payload: {'name': 'Medium Priority'},
        priority: 2,
      );

      final pending = await repository.getOperationsByStatus([SyncStatus.pending]);
      expect(pending.length, 3);
      expect(pending[0].entityId, 'p2'); // priority 1
      expect(pending[1].entityId, 'p3'); // priority 2
      expect(pending[2].entityId, 'p1'); // priority 3
    });

    test('FIFO order should be preserved within same priority', () async {
      await service.enqueue(
        entityName: 'products',
        entityId: 'p1',
        type: SyncOperationType.create,
        payload: {'name': 'First'},
        priority: 2,
      );
      // Wait a tiny bit to ensure different createdAt if necessary, 
      // though microsecondsSinceEpoch is used for ID and DateTime.now() for createdAt.
      await Future.delayed(const Duration(milliseconds: 10));
      
      await service.enqueue(
        entityName: 'products',
        entityId: 'p2',
        type: SyncOperationType.create,
        payload: {'name': 'Second'},
        priority: 2,
      );

      final pending = await repository.getOperationsByStatus([SyncStatus.pending]);
      expect(pending.length, 2);
      expect(pending[0].entityId, 'p1');
      expect(pending[1].entityId, 'p2');
    });
   group('Duplicate Protection', () {
    test('Enqueuing same entity and type should merge payload and keep older createdAt', () async {
      await service.enqueue(
        entityName: 'products',
        entityId: 'dup1',
        type: SyncOperationType.update,
        payload: {'name': 'Original', 'price': 10},
      );
      
      final firstOp = (await repository.getOperationsByStatus([SyncStatus.pending])).first;
      
      await Future.delayed(const Duration(milliseconds: 10));

      await service.enqueue(
        entityName: 'products',
        entityId: 'dup1',
        type: SyncOperationType.update,
        payload: {'price': 20, 'extra': 'new'},
      );

      final pending = await repository.getOperationsByStatus([SyncStatus.pending]);
      expect(pending.length, 1);
      expect(pending[0].id, firstOp.id);
      expect(pending[0].payload['name'], 'Original');
      expect(pending[0].payload['price'], 20);
      expect(pending[0].payload['extra'], 'new');
      expect(pending[0].createdAt, firstOp.createdAt);
    });

    test('Delete operation should override pending create/update', () async {
      await service.enqueue(
        entityName: 'products',
        entityId: 'override1',
        type: SyncOperationType.create,
        payload: {'name': 'To be deleted'},
      );

      await service.enqueue(
        entityName: 'products',
        entityId: 'override1',
        type: SyncOperationType.delete,
        payload: {},
      );

      final pending = await repository.getOperationsByStatus([SyncStatus.pending]);
      expect(pending.length, 1);
      expect(pending[0].type, SyncOperationType.delete);
      expect(pending[0].priority, 1);
    });
  });

  group('Retry Strategy with Jitter', () {
    test('Retry delay should include exponential backoff and jitter', () async {
      final op = SyncOperation(
        id: 'retry1',
        entityName: 'products',
        entityId: 'r1',
        type: SyncOperationType.create,
        payload: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        attemptCount: 0,
      );
      
      await repository.enqueue(op);
      
      // First failure (attemptCount will become 1)
      await service.updateStatus(op, SyncStatus.failed, error: 'First fail');
      
      final opAfter1 = (await repository.getAllOperations()).first;
      expect(opAfter1.attemptCount, 1);
      // baseDelay = 2^1 * 10 = 20s. jitter is 0-6s.
      expect(opAfter1.retryDelaySeconds, greaterThanOrEqualTo(20));
      expect(opAfter1.retryDelaySeconds, lessThanOrEqualTo(26));

      // Second failure (attemptCount will become 2)
      await service.updateStatus(opAfter1, SyncStatus.failed, error: 'Second fail');
      
      final opAfter2 = (await repository.getAllOperations()).first;
      expect(opAfter2.attemptCount, 2);
      // baseDelay = 2^2 * 10 = 40s. jitter is 0-12s.
      expect(opAfter2.retryDelaySeconds, greaterThanOrEqualTo(40));
      expect(opAfter2.retryDelaySeconds, lessThanOrEqualTo(52));
    });

    test('SyncEngine should respect retryDelaySeconds', () async {
      // In tests, _isTestMode is usually true, but we can try to force it or mock it.
      // SyncEngine constructor takes isTestMode.
      final fakeSync = FakeSyncService();
      final engine = SyncEngine(
        syncService: fakeSync,
        analytics: FakeAnalyticsService(),
        isTestMode: false, // Force check for retry delays
      );

      final now = DateTime.now();
      final op = SyncOperation(
        id: 'delayed_op',
        entityName: 'products',
        entityId: 'p_delayed',
        type: SyncOperationType.create,
        payload: {},
        status: SyncStatus.failed,
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now, // Just failed
        attemptCount: 1,
        retryDelaySeconds: 60, // Must wait 60s
      );
      
      await repository.enqueue(op);
      
      await engine.processQueue();
      
      final opAfter = (await repository.getAllOperations()).first;
      expect(opAfter.status, SyncStatus.failed, reason: 'Should not have processed yet');
      expect(fakeSync.upsertProductCalled, false);

      // Now "wait" by updating updatedAt
      await repository.updateOperation(op.copyWith(
        updatedAt: now.subtract(const Duration(seconds: 61)),
      ));

      await engine.processQueue();
      
      final opFinal = (await repository.getAllOperations()).first;
      expect(opFinal.status, SyncStatus.synced, reason: 'Should have processed after delay');
      expect(fakeSync.upsertProductCalled, true);
    });
  });
  });
}
