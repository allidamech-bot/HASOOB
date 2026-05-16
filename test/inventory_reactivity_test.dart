import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/product_model.dart';
import 'package:hasoob_app/data/repositories/product_repository.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';

import 'package:hasoob_app/data/services/cloud_sync_service.dart';

class FakeCloudSyncService extends Fake implements CloudSyncService {
  @override
  Stream<List<Map<String, dynamic>>> watchProducts(String businessId) => StreamController<List<Map<String, dynamic>>>().stream;
  
  @override
  Stream<List<Map<String, dynamic>>> watchSalesRecords(String businessId) => StreamController<List<Map<String, dynamic>>>().stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ProductRepository repository;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('inventory_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    SyncManager.instance.resetForTest();
    SyncManager.instance.setEngine(SyncEngine(isTestMode: true));
    ProductRepository.mockCloudSync = FakeCloudSyncService();

    repository = ProductRepository(); // Singleton instance
    
    final db = await DBHelper.database();
    
    // Ensure tables exist for testing
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
        remoteVersion INTEGER,
        localVersion INTEGER,
        conflictStrategy TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        businessId TEXT,
        name TEXT,
        unit TEXT,
        purchase_price REAL,
        extra_costs REAL,
        selling_price REAL,
        stock_qty INTEGER,
        low_stock_threshold INTEGER,
        barcode TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_movements (
        id TEXT PRIMARY KEY,
        businessId TEXT,
        productId TEXT,
        movementType TEXT,
        quantity INTEGER,
        balanceAfter INTEGER,
        referenceType TEXT,
        referenceId TEXT,
        notes TEXT,
        date TEXT,
        createdAt TEXT
      )
    ''');

    await db.delete('products');
    await db.delete('product_movements');
    await db.delete(SyncQueueRepository.tableName);
  });

  tearDown(() async {
    final db = await DBHelper.database();
    await db.close();
    await Future.delayed(const Duration(milliseconds: 50));
  });

  test('watchProducts emits updated list when addProduct is called', () async {
    const businessId = 'test_biz';
    final stream = repository.watchProducts(businessId);
    
    final emissions = <List<ProductModel>>[];
    final subscription = stream.listen(emissions.add);

    await Future.delayed(const Duration(milliseconds: 200));
    expect(emissions.length, 1);
    expect(emissions.first, isEmpty);

    const product = ProductModel(
      id: 'p1',
      businessId: businessId,
      name: 'Product 1',
      unit: 'pcs',
      purchasePrice: 80,
      sellingPrice: 100,
    );
    
    await repository.addProduct(businessId, product);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(emissions.length, greaterThan(1));
    expect(emissions.last.any((p) => p.id == 'p1'), isTrue);
    
    await subscription.cancel();
  });

  test('watchProducts emits updated list when deleteProduct is called', () async {
    const businessId = 'test_biz';
    
    final product = const ProductModel(
      id: 'p2',
      businessId: businessId,
      name: 'Product 2',
      unit: 'pcs',
      purchasePrice: 40,
      sellingPrice: 50,
    );
    await repository.addProduct(businessId, product);

    final stream = repository.watchProducts(businessId);
    final emissions = <List<ProductModel>>[];
    final subscription = stream.listen(emissions.add);

    await Future.delayed(const Duration(milliseconds: 200));
    expect(emissions.last.any((p) => p.id == 'p2'), isTrue);

    await repository.deleteProduct(businessId, 'p2');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(emissions.last.any((p) => p.id == 'p2'), isFalse);
    
    await subscription.cancel();
  });
}
