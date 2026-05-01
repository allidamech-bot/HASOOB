import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/product_model.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';
import 'package:hasoob_app/data/repositories/customer_repository.dart';
import 'package:hasoob_app/data/repositories/product_repository.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ProductRepository productRepository;
  late CustomerRepository customerRepository;
  late SyncQueueRepository syncQueueRepository;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('repo_sync_test_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    productRepository = ProductRepository();
    customerRepository = CustomerRepository();
    syncQueueRepository = SyncQueueRepository();

    final db = await DBHelper.database();
    
    // Ensure sync_operations table exists
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

    // Ensure products table exists (simplified for test)
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

    // Ensure customers table exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        businessId TEXT,
        name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        branch_id TEXT,
        created_by TEXT,
        created_at TEXT
      )
    ''');

    // Ensure product_movements table exists for DBHelper.insertProduct
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

    await syncQueueRepository.clearAll();
    await db.delete('products');
    await db.delete('customers');
    await db.delete('product_movements');
  });

  tearDown(() async {
    final db = await DBHelper.database();
    await db.close();
    await Future.delayed(const Duration(milliseconds: 50));
  });

  group('ProductRepository Sync Integration', () {
    test('addProduct should enqueue create operation', () async {
      const product = ProductModel(
        id: 'p1',
        businessId: 'b1',
        name: 'Product 1',
        unit: 'pcs',
        purchasePrice: 10.0,
        sellingPrice: 15.0,
      );

      // Repositories currently call DBHelper which calls Firebase.
      // Since we want this test to be local-only, we might need to wrap in try-catch
      // until DBHelper is decoupled from direct Firebase calls.
      try {
        await productRepository.addProduct('b1', product);
      } catch (_) {
        // Expected potential legacy Firebase sync failure in local-only test.
      }

      final pending = await SyncQueueService.instance.getPending();
      expect(pending.any((op) => op.entityId == 'p1' && op.type == SyncOperationType.create), isTrue);
    });

    test('updateProduct should enqueue update operation', () async {
      const product = ProductModel(
        id: 'p2',
        businessId: 'b1',
        name: 'Product 2 Original',
        unit: 'pcs',
        purchasePrice: 10.0,
        sellingPrice: 15.0,
      );

      try {
        await productRepository.updateProduct('b1', product);
      } catch (_) {
        // Expected potential legacy Firebase sync failure in local-only test.
      }

      final pending = await SyncQueueService.instance.getPending();
      expect(pending.any((op) => op.type == SyncOperationType.update && op.entityId == 'p2'), isTrue);
    });

    test('deleteProduct should enqueue delete operation', () async {
      try {
        await productRepository.deleteProduct('b1', 'p3');
      } catch (_) {
        // Expected potential legacy Firebase sync failure in local-only test.
      }

      final pending = await SyncQueueService.instance.getPending();
      expect(pending.any((op) => op.type == SyncOperationType.delete && op.entityId == 'p3'), isTrue);
    });
  });

  group('CustomerRepository Sync Integration', () {
    test('saveCustomer (new) should enqueue create operation', () async {
      final customerData = {
        'name': 'New Customer',
        'phone': '123456',
      };

      try {
        await customerRepository.saveCustomer('b1', customerData);
      } catch (_) {
        // Expected potential legacy Firebase sync failure in local-only test.
      }

      final pending = await SyncQueueService.instance.getPending();
      expect(pending.any((op) => op.entityName == 'customers' && op.type == SyncOperationType.create), isTrue);
    });

    test('saveCustomer (update) should enqueue update operation', () async {
      final customerData = {
        'id': 'c1',
        'name': 'Updated Customer',
        'phone': '654321',
      };

      try {
        await customerRepository.saveCustomer('b1', customerData);
      } catch (_) {
        // Expected potential legacy Firebase sync failure in local-only test.
      }

      final pending = await SyncQueueService.instance.getPending();
      expect(pending.any((op) => op.entityName == 'customers' && op.type == SyncOperationType.update && op.entityId == 'c1'), isTrue);
    });
  });
}
