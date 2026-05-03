import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/product_model.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/product_repository.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ProductRepository productRepository;
  late SyncQueueRepository syncQueueRepository;
  late SyncManager syncManager;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sync_e2e_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    productRepository = ProductRepository();
    syncQueueRepository = SyncQueueRepository();
    syncManager = SyncManager.instance;

    final db = await DBHelper.database();
    
    // Setup tables
    await db.execute('CREATE TABLE IF NOT EXISTS ${SyncQueueRepository.tableName}(id TEXT PRIMARY KEY, entityName TEXT, entityId TEXT, type TEXT, payload TEXT, status TEXT, createdAt TEXT, updatedAt TEXT, attemptCount INTEGER, lastError TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS products (id TEXT PRIMARY KEY, businessId TEXT, name TEXT, unit TEXT, purchase_price REAL, extra_costs REAL, selling_price REAL, stock_qty INTEGER, low_stock_threshold INTEGER, barcode TEXT)');
    await db.execute('CREATE TABLE IF NOT EXISTS product_movements (id TEXT PRIMARY KEY, businessId TEXT, productId TEXT, movementType TEXT, quantity INTEGER, balanceAfter INTEGER, referenceType TEXT, referenceId TEXT, notes TEXT, date TEXT, createdAt TEXT)');

    await syncQueueRepository.clearAll();
    await db.delete('products');
    
    // Reset SyncManager state
    if (syncManager.isRunning) {
        // Wait for it to finish if it was running
        await Future.delayed(const Duration(milliseconds: 100));
    }
    // We can't easily reset private fields without reflection, 
    // but we can ensure it's in a clean state for the test logic.
  });

  test('End-to-End Sync Flow: Data Entry -> Queue -> Manual Trigger -> Success', () async {
    // 1. Initial State: No sync requested
    expect(syncManager.syncRequested, isFalse, reason: 'Initially, no sync should be requested');

    // 2. Data Entry: Add a product
    final product = ProductModel(
      id: 'e2e_p1',
      businessId: 'b1',
      name: 'E2E Product',
      unit: 'pcs',
      purchasePrice: 10.0,
      sellingPrice: 15.0,
    );

    try {
      await productRepository.addProduct('b1', product);
    } catch (_) {
      // Ignore legacy Firebase failures in local test
    }

    // 3. Verify Sync Requested
    expect(syncManager.syncRequested, isTrue, reason: 'Sync should be requested after repository update');
    
    final pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 1);
    expect(pending.first.entityId, 'e2e_p1');
    expect(pending.first.status, SyncStatus.pending);

    // 4. Execute Sync Manually
    final syncFuture = syncManager.runSync();
    
    // Check running state
    expect(syncManager.isRunning, isTrue);
    
    await syncFuture;

    // 5. Verify Post-Sync State
    expect(syncManager.isRunning, isFalse);
    expect(syncManager.syncRequested, isFalse, reason: 'syncRequested should be reset after runSync');
    
    final remainingPending = await SyncQueueService.instance.getPending();
    expect(remainingPending.isEmpty, isTrue, reason: 'Queue should be empty (processed)');

    // Verify status in DB is now 'synced'
    final allOps = await syncQueueRepository.getAllOperations();
    expect(allOps.first.status, SyncStatus.synced);
  });
}
