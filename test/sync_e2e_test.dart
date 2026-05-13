import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/product_model.dart';
import 'package:hasoob_app/data/repositories/product_repository.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fakes/fake_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ProductRepository productRepository;
  late SyncQueueRepository syncQueueRepository;
  late FakeSyncService fakeSyncService;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sync_e2e_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    SyncManager.instance.resetForTest();
    fakeSyncService = FakeSyncService();
    final engine = SyncEngine(syncService: fakeSyncService);
    SyncManager.instance.setEngine(engine);

    productRepository = ProductRepository();
    syncQueueRepository = SyncQueueRepository();

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
    await db.execute('DROP TABLE IF EXISTS products');
    await db.execute('CREATE TABLE products (id TEXT PRIMARY KEY, businessId TEXT, branch_id TEXT, name TEXT, unit TEXT, purchase_price REAL, extra_costs REAL, selling_price REAL, stock_qty INTEGER, low_stock_threshold INTEGER, barcode TEXT)');
    await db.execute('DROP TABLE IF EXISTS product_movements');
    await db.execute('CREATE TABLE product_movements (id INTEGER PRIMARY KEY AUTOINCREMENT, businessId TEXT, branch_id TEXT, product_id TEXT, movement_type TEXT, quantity INTEGER, balance_after INTEGER, reference_type TEXT, reference_id TEXT, notes TEXT, date TEXT)');
    await syncQueueRepository.clearAll();
  });

  test('End-to-End Sync Flow', () async {
    expect(SyncManager.instance.syncRequested, isFalse);

    const product = ProductModel(
      id: 'e2e_p1',
      businessId: 'b1',
      name: 'E2E Product',
      unit: 'pcs',
      purchasePrice: 10.0,
      sellingPrice: 15.0,
    );

    await productRepository.addProduct('b1', product);

    final pending = await SyncQueueService.instance.getPending();
    expect(pending.length, 1);

    await SyncManager.instance.runSync();

    expect(SyncManager.instance.isRunning, isFalse);
    expect(SyncManager.instance.syncRequested, isFalse);
    
    final remainingPending = await SyncQueueService.instance.getPending();
    expect(remainingPending.isEmpty, isTrue);
    expect(fakeSyncService.callCount, 1);
  });
}
