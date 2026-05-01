import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late SyncQueueRepository repository;

  setUp(() async {
    repository = SyncQueueRepository();
    await repository.clearAll();
  });

  group('SyncQueueRepository Tests', () {
    test('Should enqueue and retrieve a sync operation', () async {
      final operation = SyncOperation(
        id: '1',
        entityName: 'products',
        entityId: 'prod_1',
        type: SyncOperationType.create,
        payload: {'name': 'Test Product', 'price': 100},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.enqueue(operation);
      final pending = await repository.getPendingOperations();

      expect(pending.length, 1);
      expect(pending.first.id, '1');
      expect(pending.first.entityName, 'products');
      expect(pending.first.payload['name'], 'Test Product');
    });

    test('Should update operation status', () async {
      final operation = SyncOperation(
        id: '2',
        entityName: 'customers',
        entityId: 'cus_1',
        type: SyncOperationType.update,
        payload: {'name': 'John Doe'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.enqueue(operation);
      
      final updatedOperation = operation.copyWith(
        status: SyncStatus.synced,
        updatedAt: DateTime.now(),
      );
      
      await repository.updateOperation(updatedOperation);
      
      final pending = await repository.getPendingOperations();
      expect(pending.isEmpty, true);
    });

    test('Should delete an operation', () async {
      final operation = SyncOperation(
        id: '3',
        entityName: 'invoices',
        entityId: 'inv_1',
        type: SyncOperationType.delete,
        payload: {'id': 'inv_1'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.enqueue(operation);
      await repository.deleteOperation('3');
      
      final pending = await repository.getPendingOperations();
      expect(pending.isEmpty, true);
    });
  group('SyncOperation Model Tests', () {
      test('toMap and fromMap should be consistent', () {
        final now = DateTime.now();
        final operation = SyncOperation(
          id: '4',
          entityName: 'products',
          entityId: 'p1',
          type: SyncOperationType.create,
          payload: {'a': 1},
          createdAt: now,
          updatedAt: now,
        );

        final map = operation.toMap();
        final restored = SyncOperation.fromMap(map);

        expect(restored.id, operation.id);
        expect(restored.entityName, operation.entityName);
        expect(restored.type, operation.type);
        expect(restored.payload, operation.payload);
        // Compare ISO strings to avoid millisecond precision issues in some environments
        expect(restored.createdAt.toIso8601String(), operation.createdAt.toIso8601String());
      });
    });
  });
}
