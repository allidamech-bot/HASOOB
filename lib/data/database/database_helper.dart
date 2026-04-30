import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/app_currency.dart';
import '../models/product_model.dart';
import '../services/cloud_sync_service.dart';
import '../services/sync_manager.dart';


class DBHelper {
  static const _databaseName = 'hasoob_al_muheet_v3.db';
  static const _databaseVersion = 12;

  static const _cashAccountCode = '101';
  static const _inventoryAccountCode = '102';
  static const _receivablesAccountCode = '103';
  static const _payablesAccountCode = '201';
  static const _salesAccountCode = '401';
  static const _cogsAccountCode = '501';

  static const List<Map<String, dynamic>> _defaultAccounts = [
    {
      'name': 'الصندوق',
      'code': _cashAccountCode,
      'balance': 0.0,
      'category': 'asset',
    },
    {
      'name': 'المخزون',
      'code': _inventoryAccountCode,
      'balance': 0.0,
      'category': 'asset',
    },
    {
      'name': 'العملاء',
      'code': _receivablesAccountCode,
      'balance': 0.0,
      'category': 'asset',
    },
    {
      'name': 'الموردون',
      'code': _payablesAccountCode,
      'balance': 0.0,
      'category': 'liability',
    },
    {
      'name': 'المبيعات',
      'code': _salesAccountCode,
      'balance': 0.0,
      'category': 'revenue',
    },
    {
      'name': 'تكلفة البضاعة المباعة',
      'code': _cogsAccountCode,
      'balance': 0.0,
      'category': 'expense',
    },
  ];

  static Future<Database> database() async {
    final dbPath = await getDatabasesPath();

    return openDatabase(
      join(dbPath, _databaseName),
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sales_records(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id TEXT,
              product_name TEXT,
              qty INTEGER,
              selling_price REAL,
              landed_cost REAL,
              total_sale REAL,
              total_profit REAL,
              date TEXT
            )
          ''');
        }

        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }

        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }

        if (oldVersion < 5) {
          await _upgradeToV5(db);
        }

        if (oldVersion < 6) {
          await _upgradeToV6(db);
        }

        if (oldVersion < 7) {
          await _upgradeToV7(db);
        }

        if (oldVersion < 8) {
          await _upgradeToV8(db);
        }

        if (oldVersion < 9) {
          await _upgradeToV9(db);
        }

        if (oldVersion < 10) {
          await _upgradeToV10(db);
        }

        if (oldVersion < 11) {
          await _upgradeToV11(db);
        }

        if (oldVersion < 12) {
          await _upgradeToV12(db);
        }

        await _repairAccountNamesForV12(db);
      },
      onOpen: (db) async {
        await _createPerformanceIndexes(db);
      },
    );
  }

  static Future<void> _repairAccountNamesForV12(Database db) async {
    // This is called during upgrade. Since we don't have businessId here,
    // we only repair if we can identify businessIds from existing accounts.
    final result = await db.rawQuery('SELECT DISTINCT businessId FROM accounts WHERE businessId IS NOT NULL');
    for (final row in result) {
      final bId = row['businessId']?.toString();
      if (bId != null) {
        await _ensureDefaultAccounts(db, bId);
        await _repairAccountNames(db, bId);
      }
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessId TEXT,
        name TEXT,
        code TEXT,
        balance REAL DEFAULT 0.0,
        category TEXT DEFAULT 'asset',
        UNIQUE(code, businessId)
      )
    ''');

    await db.execute('''
      CREATE TABLE journal_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debit_account_id INTEGER,
        credit_account_id INTEGER,
        amount REAL,
        description TEXT,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products(
        id TEXT PRIMARY KEY,
        businessId TEXT,
        name TEXT,
        unit TEXT,
        purchase_price REAL,
        extra_costs REAL,
        selling_price REAL,
        stock_qty INTEGER,
        low_stock_threshold INTEGER DEFAULT 5,
        barcode TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessId TEXT,
        product_id TEXT,
        product_name TEXT,
        qty INTEGER,
        customer_name TEXT,
        sale_note TEXT,
        currency_code TEXT,
        selling_price REAL,
        landed_cost REAL,
        total_sale REAL,
        total_profit REAL,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE product_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessId TEXT,
        product_id TEXT,
        movement_type TEXT,
        quantity INTEGER,
        balance_after INTEGER,
        reference_type TEXT,
        reference_id TEXT,
        notes TEXT,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers(
        id TEXT PRIMARY KEY,
        businessId TEXT,
        name TEXT,
        phone TEXT,
        notes TEXT,
        branch_id TEXT,
        created_by TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE quotations(
        id TEXT PRIMARY KEY,
        businessId TEXT,
        quotation_number TEXT UNIQUE,
        customer_id TEXT,
        status TEXT,
        issue_date TEXT,
        expiry_date TEXT,
        subtotal REAL,
        total REAL,
        notes TEXT,
        currency_code TEXT,
        created_by TEXT,
        branch_id TEXT,
        converted_invoice_id TEXT,
        pdf_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE quotation_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessId TEXT,
        quotation_id TEXT,
        product_id TEXT,
        product_name TEXT,
        quantity INTEGER,
        unit_price REAL,
        line_total REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE document_counters(
        key TEXT PRIMARY KEY,
        last_value INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
        id TEXT PRIMARY KEY,
        businessId TEXT,
        invoice_number TEXT UNIQUE,
        customer_id TEXT,
        quotation_id TEXT,
        status TEXT,
        issue_date TEXT,
        due_date TEXT,
        subtotal REAL,
        total REAL,
        paid_amount REAL,
        remaining_amount REAL,
        notes TEXT,
        currency_code TEXT,
        created_by TEXT,
        branch_id TEXT,
        payment_method TEXT,
        accounting_posted INTEGER DEFAULT 0,
        pdf_path TEXT,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        businessId TEXT,
        invoice_id TEXT,
        product_id TEXT,
        product_name TEXT,
        quantity INTEGER,
        unit_price REAL,
        line_total REAL,
        landed_cost REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments(
        id TEXT PRIMARY KEY,
        businessId TEXT,
        invoice_id TEXT,
        customer_id TEXT,
        amount REAL,
        payment_method TEXT,
        payment_date TEXT,
        note TEXT,
        created_by TEXT,
        branch_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE business_profile(
        id TEXT PRIMARY KEY,
        businessId TEXT,
        business_name TEXT,
        trade_name TEXT,
        logo_path TEXT,
        phone TEXT,
        whatsapp TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        registration_number TEXT,
        default_invoice_notes TEXT,
        default_quotation_notes TEXT,
        payment_terms_footer TEXT,
        branch_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue(
        id TEXT PRIMARY KEY,
        entity_type TEXT,
        entity_id TEXT,
        action TEXT,
        payload TEXT,
        created_at TEXT,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await _createPerformanceIndexes(db);
  }

  static Future<void> _upgradeToV3(Database db) async {
    await _ensureColumn(
      db,
      table: 'products',
      column: 'low_stock_threshold',
      definition: 'INTEGER DEFAULT 5',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'barcode',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'accounts',
      column: 'category',
      definition: "TEXT DEFAULT 'asset'",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT,
        movement_type TEXT,
        quantity INTEGER,
        balance_after INTEGER,
        reference_type TEXT,
        reference_id TEXT,
        notes TEXT,
        date TEXT
      )
    ''');
  }

  static Future<void> _upgradeToV4(Database db) async {
    // Legacy upgrade V4 used to call _ensureDefaultAccounts without businessId.
    // Since multi-tenancy was introduced in V12, we can't easily fix V4.
    // However, _repairAccountNamesForV12 will handle initialization for all tenants.
  }

  static Future<void> _upgradeToV5(Database db) async {
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'customer_name',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'sale_note',
      definition: 'TEXT',
    );
  }

  static Future<void> _upgradeToV6(Database db) async {
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'sale_currency_code',
      definition: "TEXT DEFAULT '${AppCurrency.baseCurrencyCode}'",
    );
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'base_currency_code',
      definition: "TEXT DEFAULT '${AppCurrency.baseCurrencyCode}'",
    );
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'exchange_rate',
      definition: 'REAL DEFAULT 1.0',
    );
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'original_unit_price',
      definition: 'REAL',
    );
    await _ensureColumn(
      db,
      table: 'sales_records',
      column: 'original_total_sale',
      definition: 'REAL',
    );
  }

  static Future<void> _upgradeToV7(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers(
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        notes TEXT,
        branch_id TEXT,
        created_by TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotations(
        id TEXT PRIMARY KEY,
        quotation_number TEXT UNIQUE,
        customer_id TEXT,
        status TEXT,
        issue_date TEXT,
        expiry_date TEXT,
        subtotal REAL,
        total REAL,
        notes TEXT,
        currency_code TEXT,
        base_currency_code TEXT,
        exchange_rate REAL,
        created_by TEXT,
        branch_id TEXT,
        converted_invoice_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotation_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quotation_id TEXT,
        product_id TEXT,
        product_name TEXT,
        quantity INTEGER,
        unit_price REAL,
        line_total REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices(
        id TEXT PRIMARY KEY,
        invoice_number TEXT UNIQUE,
        customer_id TEXT,
        quotation_id TEXT,
        status TEXT,
        issue_date TEXT,
        due_date TEXT,
        subtotal REAL,
        total REAL,
        paid_amount REAL,
        remaining_amount REAL,
        notes TEXT,
        currency_code TEXT,
        base_currency_code TEXT,
        exchange_rate REAL,
        created_by TEXT,
        branch_id TEXT,
        payment_method TEXT,
        accounting_posted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id TEXT,
        product_id TEXT,
        product_name TEXT,
        quantity INTEGER,
        unit_price REAL,
        line_total REAL,
        landed_cost REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments(
        id TEXT PRIMARY KEY,
        invoice_id TEXT,
        customer_id TEXT,
        amount REAL,
        payment_method TEXT,
        payment_date TEXT,
        note TEXT,
        created_by TEXT,
        branch_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_profile(
        id INTEGER PRIMARY KEY,
        business_name TEXT,
        trade_name TEXT,
        logo_path TEXT,
        phone TEXT,
        whatsapp TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        registration_number TEXT,
        default_invoice_notes TEXT,
        default_quotation_notes TEXT,
        payment_terms_footer TEXT,
        branch_id TEXT
      )
    ''');
  }

  static Future<void> _upgradeToV8(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_counters(
        key TEXT PRIMARY KEY,
        last_value INTEGER NOT NULL
      )
    ''');

    await _ensureColumn(
      db,
      table: 'invoices',
      column: 'pdf_path',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'invoices',
      column: 'discount',
      definition: 'REAL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'invoices',
      column: 'tax',
      definition: 'REAL DEFAULT 0',
    );

    await _createPerformanceIndexes(db);
  }

  static Future<void> _upgradeToV9(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue(
        id TEXT PRIMARY KEY,
        entity_type TEXT,
        entity_id TEXT,
        action TEXT,
        payload TEXT,
        created_at TEXT,
        retry_count INTEGER DEFAULT 0
      )
    ''');
  }

  static Future<void> _upgradeToV10(Database db) async {
    await _rebuildSalesRecordsForManualCurrency(db);
    await _rebuildQuotationsForManualCurrency(db);
    await _rebuildInvoicesForManualCurrency(db);
  }

  static Future<void> _upgradeToV11(Database db) async {
    // V11 was a placeholder for transition or specific fixes.
    // Ensure all tables have necessary indexes if not already created.
    await _createPerformanceIndexes(db);
  }

  static Future<void> _upgradeToV12(Database db) async {
    final tables = [
      'products',
      'invoices',
      'quotations',
      'customers',
      'payments',
      'product_movements',
      'sales_records',
      'accounts',
      'invoice_items',
      'quotation_items',
      'journal_entries',
      'business_profile',
    ];
    for (final table in tables) {
      await _ensureColumn(
        db,
        table: table,
        column: 'businessId',
        definition: 'TEXT',
      );
    }
  }

  static Future<void> _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _rebuildSalesRecordsForManualCurrency(Database db) async {
    await db.execute('DROP TABLE IF EXISTS sales_records_v10');
    await db.execute('''
      CREATE TABLE sales_records_v10(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT,
        product_name TEXT,
        qty INTEGER,
        customer_name TEXT,
        sale_note TEXT,
        currency_code TEXT,
        selling_price REAL,
        landed_cost REAL,
        total_sale REAL,
        total_profit REAL,
        date TEXT
      )
    ''');

    await db.execute('''
      INSERT INTO sales_records_v10(
        id,
        product_id,
        product_name,
        qty,
        customer_name,
        sale_note,
        currency_code,
        selling_price,
        landed_cost,
        total_sale,
        total_profit,
        date
      )
      SELECT
        id,
        product_id,
        product_name,
        qty,
        customer_name,
        sale_note,
        COALESCE(NULLIF(TRIM(sale_currency_code), ''), ''),
        COALESCE(original_unit_price, selling_price, 0),
        landed_cost,
        COALESCE(original_total_sale, total_sale, 0),
        total_profit,
        date
      FROM sales_records
    ''');

    await db.execute('DROP TABLE sales_records');
    await db.execute('ALTER TABLE sales_records_v10 RENAME TO sales_records');
  }

  static Future<void> _rebuildQuotationsForManualCurrency(Database db) async {
    await db.execute('DROP TABLE IF EXISTS quotations_v10');
    await db.execute('''
      CREATE TABLE quotations_v10(
        id TEXT PRIMARY KEY,
        quotation_number TEXT UNIQUE,
        customer_id TEXT,
        status TEXT,
        issue_date TEXT,
        expiry_date TEXT,
        subtotal REAL,
        total REAL,
        notes TEXT,
        currency_code TEXT,
        created_by TEXT,
        branch_id TEXT,
        converted_invoice_id TEXT
      )
    ''');

    await db.execute('''
      INSERT INTO quotations_v10(
        id,
        quotation_number,
        customer_id,
        status,
        issue_date,
        expiry_date,
        subtotal,
        total,
        notes,
        currency_code,
        created_by,
        branch_id,
        converted_invoice_id
      )
      SELECT
        id,
        quotation_number,
        customer_id,
        status,
        issue_date,
        expiry_date,
        subtotal,
        total,
        notes,
        COALESCE(NULLIF(TRIM(currency_code), ''), ''),
        created_by,
        branch_id,
        converted_invoice_id
      FROM quotations
    ''');

    await db.execute('DROP TABLE quotations');
    await db.execute('ALTER TABLE quotations_v10 RENAME TO quotations');
  }

  static Future<void> _rebuildInvoicesForManualCurrency(Database db) async {
    await db.execute('DROP TABLE IF EXISTS invoices_v10');
    await db.execute('''
      CREATE TABLE invoices_v10(
        id TEXT PRIMARY KEY,
        invoice_number TEXT UNIQUE,
        customer_id TEXT,
        quotation_id TEXT,
        status TEXT,
        issue_date TEXT,
        due_date TEXT,
        subtotal REAL,
        total REAL,
        paid_amount REAL,
        remaining_amount REAL,
        notes TEXT,
        currency_code TEXT,
        created_by TEXT,
        branch_id TEXT,
        payment_method TEXT,
        accounting_posted INTEGER DEFAULT 0,
        pdf_path TEXT,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      INSERT INTO invoices_v10(
        id,
        invoice_number,
        customer_id,
        quotation_id,
        status,
        issue_date,
        due_date,
        subtotal,
        total,
        paid_amount,
        remaining_amount,
        notes,
        currency_code,
        created_by,
        branch_id,
        payment_method,
        accounting_posted,
        pdf_path,
        discount,
        tax
      )
      SELECT
        id,
        invoice_number,
        customer_id,
        quotation_id,
        status,
        issue_date,
        due_date,
        subtotal,
        total,
        paid_amount,
        remaining_amount,
        notes,
        COALESCE(NULLIF(TRIM(currency_code), ''), ''),
        created_by,
        branch_id,
        payment_method,
        accounting_posted,
        pdf_path,
        discount,
        tax
      FROM invoices
    ''');

    await db.execute('DROP TABLE invoices');
    await db.execute('ALTER TABLE invoices_v10 RENAME TO invoices');
  }

  static Future<void> _ensureDefaultAccounts(
    DatabaseExecutor db,
    String businessId,
  ) async {
    for (final account in _defaultAccounts) {
      final payload = {
        ...account,
        'businessId': businessId,
      };
      await db.insert(
        'accounts',
        payload,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _repairAccountNames(
    DatabaseExecutor db,
    String businessId,
  ) async {
    for (final account in _defaultAccounts) {
      await db.update(
        'accounts',
        {
          'name': account['name'],
          'category': account['category'],
        },
        where: 'code = ? AND businessId = ?',
        whereArgs: [account['code'], businessId],
      );
    }
  }

  static Future<String> insertProduct(Map<String, dynamic> data) async {
    final db = await database();
    final payload = Map<String, dynamic>.from(data)
      ..putIfAbsent('low_stock_threshold', () => 5);
    final businessId = payload['businessId']?.toString() ?? '';

    await db.insert(
      'products',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _recordProductMovement(
      db,
      businessId: businessId,
      productId: payload['id'].toString(),
      movementType: 'opening',
      quantity: _toInt(payload['stock_qty']),
      balanceAfter: _toInt(payload['stock_qty']),
      referenceType: 'product',
      referenceId: payload['id'].toString(),
      notes: 'إضافة رصيد افتتاحي للصنف ${payload['name']}',
    );

    await CloudSyncService.instance.upsertProduct(_withOwner(payload));

    return payload['id'].toString();
  }

  static Future<List<Map<String, dynamic>>> getProducts(String businessId) async {
    final db = await database();
    return db.query(
      'products',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  static Future<Map<String, dynamic>?> getProductById(String businessId, String id) async {
    final db = await database();
    final result = await db.query(
      'products',
      where: 'id = ? AND businessId = ?',
      whereArgs: [id, businessId],
    );
    return result.isEmpty ? null : result.first;
  }

  static Future<int> updateProduct(Map<String, dynamic> data) async {
    final db = await database();
    final businessId = data['businessId']?.toString() ?? '';
    final previous = await getProductById(data['id'].toString(), businessId);
    final payload = Map<String, dynamic>.from(data)
      ..putIfAbsent('low_stock_threshold', () => 5);

    final result = await db.update(
      'products',
      payload,
      where: 'id = ? AND businessId = ?',
      whereArgs: [data['id'], businessId],
    );

    if (result > 0 && previous != null) {
      final previousQty = _toInt(previous['stock_qty']);
      final nextQty = _toInt(payload['stock_qty']);
      if (previousQty != nextQty) {
        await _recordProductMovement(
          db,
          businessId: businessId,
          productId: payload['id'].toString(),
          movementType: 'adjustment',
          quantity: nextQty - previousQty,
          balanceAfter: nextQty,
          referenceType: 'product',
          referenceId: payload['id'].toString(),
          notes: 'تعديل رصيد الصنف ${payload['name']}',
        );
      }

      await CloudSyncService.instance.upsertProduct(_withOwner(payload));
    }

    return result;
  }

  static Future<int> deleteProduct(String businessId, String id) async {
    final db = await database();
    final result = await db.delete(
      'products',
      where: 'id = ? AND businessId = ?',
      whereArgs: [id, businessId],
    );

    if (result > 0) {
      await CloudSyncService.instance.deleteProduct(id);
    }

    return result;
  }

  static Future<void> addJournalEntry({
    required String businessId,
    required int debitId,
    required int creditId,
    required double amount,
    required String desc,
  }) async {
    final db = await database();
    final entryDate = DateTime.now().toIso8601String();
    int? journalEntryId;

    await db.transaction((txn) async {
      journalEntryId = await _postJournalEntry(
        txn,
        businessId: businessId,
        debitAccountId: debitId,
        creditAccountId: creditId,
        amount: amount,
        description: desc,
        date: entryDate,
      );
    });

    final accounts = await db.query(
      'accounts',
      where: 'id IN (?, ?) AND businessId = ?',
      whereArgs: [debitId, creditId, businessId],
    );

    await CloudSyncService.instance.addJournalEntry(_withOwner({
      'id': journalEntryId,
      'businessId': businessId,
      'debit_account_id': debitId,
      'credit_account_id': creditId,
      'amount': amount,
      'description': desc,
      'date': entryDate,
    }));

    await CloudSyncService.instance.syncAccounts(_withOwnerList(accounts));
  }

  static Future<void> sellProduct({
    required String businessId,
    required String productId,
    required int qty,
    required double sellingPrice,
    String? customerName,
    String? saleNote,
    String? currencyCode,
  }) async {
    final db = await database();
    Map<String, dynamic>? updatedProductData;
    Map<String, dynamic>? saleRecordData;
    List<Map<String, dynamic>> journalEntriesData = const [];
    List<int> touchedAccountIds = const [];

    await db.transaction((txn) async {
      await _ensureDefaultAccounts(txn, businessId);
      await _repairAccountNames(txn, businessId);

      final productRows = await txn.query(
        'products',
        where: 'id = ? AND businessId = ?',
        whereArgs: [productId, businessId],
      );

      if (productRows.isEmpty) {
        throw Exception('تعذر العثور على الصنف المطلوب.');
      }

      final productRow = productRows.first;
      final currentQty = _toInt(productRow['stock_qty']);

      if (qty <= 0) {
        throw Exception('الكمية المباعة يجب أن تكون أكبر من صفر.');
      }

      if (currentQty < qty) {
        throw Exception('الكمية المطلوبة أكبر من المخزون المتاح.');
      }

      final purchasePrice = _toDouble(productRow['purchase_price']);
      final extraCosts = _toDouble(productRow['extra_costs']);
      final landedCost = purchasePrice + extraCosts;
      final totalSale = sellingPrice * qty;
      final totalCogs = landedCost * qty;
      final totalProfit = (sellingPrice - landedCost) * qty;
      final productName = productRow['name'].toString();
      final updatedQty = currentQty - qty;
      final transactionDate = DateTime.now().toIso8601String();
      final normalizedCustomerName = customerName?.trim();
      final normalizedSaleNote = saleNote?.trim();
      final normalizedCurrencyCode = AppCurrency.sanitizeLabel(currencyCode);
      _buildSaleDescription(
        productName: productName,
        customerName: normalizedCustomerName,
        note: normalizedSaleNote,
      );

      if (sellingPrice < 0) {
        throw Exception('سعر البيع المستخدم يجب أن يكون صفراً أو أكبر.');
      }

      final cashAccountId = await _requireAccountId(txn, _cashAccountCode, businessId);
      final inventoryAccountId = await _requireAccountId(
        txn,
        _inventoryAccountCode,
        businessId,
      );
      final salesAccountId = await _requireAccountId(txn, _salesAccountCode, businessId);
      final cogsAccountId = await _requireAccountId(txn, _cogsAccountCode, businessId);

      await txn.update(
        'products',
        {'stock_qty': updatedQty},
        where: 'id = ? AND businessId = ?',
        whereArgs: [productId, businessId],
      );

      final journalEntries = <Map<String, dynamic>>[];

      final saleJournalEntryId = await _postJournalEntry(
        txn,
        businessId: businessId,
        debitAccountId: cashAccountId,
        creditAccountId: salesAccountId,
        amount: totalSale,
        description: 'بيع الصنف: $productName',
        date: transactionDate,
      );
      journalEntries.add({
        'id': saleJournalEntryId,
        'businessId': businessId,
        'debit_account_id': cashAccountId,
        'credit_account_id': salesAccountId,
        'amount': totalSale,
        'description': 'بيع الصنف: $productName',
        'date': transactionDate,
      });

      if (totalCogs > 0) {
        final cogsJournalEntryId = await _postJournalEntry(
          txn,
          businessId: businessId,
          debitAccountId: cogsAccountId,
          creditAccountId: inventoryAccountId,
          amount: totalCogs,
          description: 'تكلفة البضاعة المباعة: $productName',
          date: transactionDate,
        );
        journalEntries.add({
          'id': cogsJournalEntryId,
          'businessId': businessId,
          'debit_account_id': cogsAccountId,
          'credit_account_id': inventoryAccountId,
          'amount': totalCogs,
          'description': 'تكلفة البضاعة المباعة: $productName',
          'date': transactionDate,
        });
      }

      final saleRecordId = await txn.insert('sales_records', {
        'businessId': businessId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'customer_name': normalizedCustomerName?.isEmpty ?? true
            ? null
            : normalizedCustomerName,
        'sale_note':
            normalizedSaleNote?.isEmpty ?? true ? null : normalizedSaleNote,
        'currency_code': normalizedCurrencyCode,
        'selling_price': sellingPrice,
        'landed_cost': landedCost,
        'total_sale': totalSale,
        'total_profit': totalProfit,
        'date': transactionDate,
      });

      await txn.insert('product_movements', {
        'businessId': businessId,
        'product_id': productId,
        'movement_type': 'sale',
        'quantity': -qty,
        'balance_after': updatedQty,
        'reference_type': 'sale',
        'reference_id': saleRecordId.toString(),
        'notes': 'بيع $qty من $productName',
        'date': transactionDate,
      });

      updatedProductData = {
        ...Map<String, dynamic>.from(productRow),
        'stock_qty': updatedQty,
      };
      journalEntriesData = journalEntries;
      touchedAccountIds = [
        cashAccountId,
        inventoryAccountId,
        salesAccountId,
        cogsAccountId,
      ];
      saleRecordData = {
        'id': saleRecordId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'customer_name': normalizedCustomerName?.isEmpty ?? true
            ? null
            : normalizedCustomerName,
        'sale_note':
            normalizedSaleNote?.isEmpty ?? true ? null : normalizedSaleNote,
        'currency_code': normalizedCurrencyCode,
        'selling_price': sellingPrice,
        'landed_cost': landedCost,
        'total_sale': totalSale,
        'total_profit': totalProfit,
        'date': transactionDate,
      };
    });

    final accounts = touchedAccountIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await db.query(
            'accounts',
            where:
                'id IN (${List.filled(touchedAccountIds.length, '?').join(', ')}) AND businessId = ?',
            whereArgs: [...touchedAccountIds, businessId],
          );

    if (updatedProductData != null) {
      await CloudSyncService.instance.upsertProduct(
        _withOwner(updatedProductData!),
      );
    }

    if (saleRecordData != null) {
      await CloudSyncService.instance.addSaleRecord(_withOwner(saleRecordData!));
    }

    for (final journalEntryData in journalEntriesData) {
      await CloudSyncService.instance.addJournalEntry(_withOwner(journalEntryData));
    }

    if (accounts.isNotEmpty) {
      await CloudSyncService.instance.syncAccounts(_withOwnerList(accounts));
    }
  }

  static Future<void> _recordProductMovement(
    DatabaseExecutor db, {
    required String businessId,
    required String productId,
    required String movementType,
    required int quantity,
    required int balanceAfter,
    required String referenceType,
    required String referenceId,
    required String notes,
  }) async {
    final payload = {
      'businessId': businessId,
      'product_id': productId,
      'movement_type': movementType,
      'quantity': quantity,
      'balance_after': balanceAfter,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'notes': notes,
      'date': DateTime.now().toIso8601String(),
    };
    final movementId = await db.insert('product_movements', payload);
    await CloudSyncService.instance.upsertProductMovement(_withOwner({
      'id': movementId,
      ...payload,
    }));
  }

  static Future<void> applyInventoryAdjustment({
    required String businessId,
    required String productId,
    int? newStockQty,
    double? newPurchasePrice,
    double? newExtraCosts,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('يرجى إدخال سبب واضح للتسوية.');
    }

    final db = await database();
    Map<String, dynamic>? updatedProductData;
    List<Map<String, dynamic>> journalEntriesData = const [];
    List<int> touchedAccountIds = const [];

    await db.transaction((txn) async {
      await _ensureDefaultAccounts(txn, businessId);
      await _repairAccountNames(txn, businessId);

      final productRows = await txn.query(
        'products',
        where: 'id = ? AND businessId = ?',
        whereArgs: [productId, businessId],
      );

      if (productRows.isEmpty) {
        throw Exception('تعذر العثور على الصنف المطلوب.');
      }

      final productRow = productRows.first;
      final currentQty = _toInt(productRow['stock_qty']);
      final currentPurchasePrice = _toDouble(productRow['purchase_price']);
      final currentExtraCosts = _toDouble(productRow['extra_costs']);
      final currentLandedCost = currentPurchasePrice + currentExtraCosts;

      final nextQty = newStockQty ?? currentQty;
      final nextPurchasePrice = newPurchasePrice ?? currentPurchasePrice;
      final nextExtraCosts = newExtraCosts ?? currentExtraCosts;
      final nextLandedCost = nextPurchasePrice + nextExtraCosts;

      final stockChanged = nextQty != currentQty;
      final costChanged = nextPurchasePrice != currentPurchasePrice ||
          nextExtraCosts != currentExtraCosts;

      if (!stockChanged && !costChanged) {
        throw Exception('لم يتم إدخال أي تغيير فعلي للتسوية.');
      }

      if (stockChanged && costChanged) {
        throw Exception(
          'للحفاظ على سلامة القيود، عدّل الكمية أو التكلفة في كل تسوية بشكل منفصل.',
        );
      }

      if (nextQty < 0) {
        throw Exception('لا يمكن أن يكون الرصيد الناتج أقل من صفر.');
      }

      final productName = productRow['name'].toString();
      final transactionDate = DateTime.now().toIso8601String();
      final inventoryAccountId = await _requireAccountId(
        txn,
        _inventoryAccountCode,
        businessId,
      );
      final payablesAccountId = await _requireAccountId(txn, _payablesAccountCode, businessId);
      final cogsAccountId = await _requireAccountId(txn, _cogsAccountCode, businessId);
      final journalEntries = <Map<String, dynamic>>[];

      if (stockChanged) {
        final qtyDelta = nextQty - currentQty;
        final amount = currentLandedCost * qtyDelta.abs();

        await txn.update(
          'products',
          {'stock_qty': nextQty},
          where: 'id = ? AND businessId = ?',
          whereArgs: [productId, businessId],
        );

        await _recordProductMovement(
          txn,
          businessId: businessId,
          productId: productId,
          movementType: 'adjustment',
          quantity: qtyDelta,
          balanceAfter: nextQty,
          referenceType: 'adjustment',
          referenceId: productId,
          notes: 'تسوية مخزون: $trimmedReason',
        );

        if (amount > 0) {
          if (qtyDelta > 0) {
            final journalEntryId = await _postJournalEntry(
              txn,
              businessId: businessId,
              debitAccountId: inventoryAccountId,
              creditAccountId: payablesAccountId,
              amount: amount,
              description: 'زيادة مخزون للصنف $productName - $trimmedReason',
              date: transactionDate,
            );
            journalEntries.add({
              'id': journalEntryId,
              'businessId': businessId,
              'debit_account_id': inventoryAccountId,
              'credit_account_id': payablesAccountId,
              'amount': amount,
              'description': 'زيادة مخزون للصنف $productName - $trimmedReason',
              'date': transactionDate,
            });
          } else {
            final journalEntryId = await _postJournalEntry(
              txn,
              businessId: businessId,
              debitAccountId: cogsAccountId,
              creditAccountId: inventoryAccountId,
              amount: amount,
              description: 'خفض مخزون للصنف $productName - $trimmedReason',
              date: transactionDate,
            );
            journalEntries.add({
              'id': journalEntryId,
              'businessId': businessId,
              'debit_account_id': cogsAccountId,
              'credit_account_id': inventoryAccountId,
              'amount': amount,
              'description': 'خفض مخزون للصنف $productName - $trimmedReason',
              'date': transactionDate,
            });
          }
        }
      } else if (costChanged) {
        await txn.update(
          'products',
          {
            'purchase_price': nextPurchasePrice,
            'extra_costs': nextExtraCosts,
          },
          where: 'id = ? AND businessId = ?',
          whereArgs: [productId, businessId],
        );

        await _recordProductMovement(
          txn,
          businessId: businessId,
          productId: productId,
          movementType: 'cost_adjustment',
          quantity: 0,
          balanceAfter: currentQty,
          referenceType: 'adjustment',
          referenceId: productId,
          notes: 'تسوية تكلفة: $trimmedReason',
        );

        final amount = (nextLandedCost - currentLandedCost) * currentQty;
        if (amount > 0) {
          final journalEntryId = await _postJournalEntry(
            txn,
            businessId: businessId,
            debitAccountId: inventoryAccountId,
            creditAccountId: payablesAccountId,
            amount: amount,
            description: 'زيادة تكلفة الصنف $productName - $trimmedReason',
            date: transactionDate,
          );
          journalEntries.add({
            'id': journalEntryId,
            'businessId': businessId,
            'debit_account_id': inventoryAccountId,
            'credit_account_id': payablesAccountId,
            'amount': amount,
            'description': 'زيادة تكلفة الصنف $productName - $trimmedReason',
            'date': transactionDate,
          });
        } else if (amount < 0) {
          final journalEntryId = await _postJournalEntry(
            txn,
            businessId: businessId,
            debitAccountId: payablesAccountId,
            creditAccountId: inventoryAccountId,
            amount: amount.abs(),
            description: 'خفض تكلفة الصنف $productName - $trimmedReason',
            date: transactionDate,
          );
          journalEntries.add({
            'id': journalEntryId,
            'businessId': businessId,
            'debit_account_id': payablesAccountId,
            'credit_account_id': inventoryAccountId,
            'amount': amount.abs(),
            'description': 'خفض تكلفة الصنف $productName - $trimmedReason',
            'date': transactionDate,
          });
        }
      }

      final refreshedRows = await txn.query(
        'products',
        where: 'id = ? AND businessId = ?',
        whereArgs: [productId, businessId],
        limit: 1,
      );
      if (refreshedRows.isNotEmpty) {
        updatedProductData = Map<String, dynamic>.from(refreshedRows.first);
      }
      journalEntriesData = journalEntries;
      touchedAccountIds = [
        inventoryAccountId,
        payablesAccountId,
        cogsAccountId,
      ];
    });

    if (updatedProductData != null) {
      await CloudSyncService.instance.upsertProduct(
        _withOwner(updatedProductData!),
      );
    }

    for (final journalEntryData in journalEntriesData) {
      await CloudSyncService.instance.addJournalEntry(_withOwner(journalEntryData));
    }

    if (touchedAccountIds.isNotEmpty) {
      final accounts = await db.query(
        'accounts',
        where: 'id IN (${List.filled(touchedAccountIds.length, '?').join(', ')}) AND businessId = ?',
        whereArgs: [...touchedAccountIds, businessId],
      );
      await CloudSyncService.instance.syncAccounts(_withOwnerList(accounts));
    }
  }

  static Future<List<Map<String, dynamic>>> getCustomers(String businessId) async {
    final db = await database();
    return db.rawQuery('''
      SELECT c.*,
             COALESCE((
               SELECT SUM(remaining_amount)
               FROM invoices i
               WHERE i.customer_id = c.id AND i.businessId = c.businessId
                 AND COALESCE(i.status, '') NOT IN ('draft', 'cancelled')
             ), 0) AS outstanding_balance
      FROM customers c
      WHERE c.businessId = ?
      ORDER BY c.name COLLATE NOCASE ASC
    ''', [businessId]);
  }

  static Future<String> saveCustomer(Map<String, dynamic> data) async {
    final db = await database();
    final now = DateTime.now().toIso8601String();
    final id = data['id']?.toString().trim().isNotEmpty == true
        ? data['id'].toString()
        : _newTextId('CUS');
    final payload = {
      'id': id,
      'businessId': data['businessId']?.toString() ?? '',
      'name': data['name']?.toString().trim() ?? '',
      'phone': data['phone']?.toString().trim(),
      'notes': data['notes']?.toString().trim(),
      'branch_id': data['branch_id']?.toString().trim(),
      'created_by': data['created_by']?.toString().trim(),
      'created_at': data['created_at']?.toString().trim().isNotEmpty == true
          ? data['created_at'].toString()
          : now,
    };

    if ((payload['name'] as String).isEmpty) {
      throw Exception('اسم العميل مطلوب.');
    }

    await db.insert(
      'customers',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await CloudSyncService.instance.upsertCustomer(_withOwner(payload));
    return id;
  }

  static Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database();
    final normalizedEntityId = entityId.toString();
    final normalizedPayload = Map<String, dynamic>.from(payload)
      ..['id'] = normalizedEntityId;

    await db.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, normalizedEntityId],
    );

    await db.insert(
      'sync_queue',
      {
        'id': _newTextId('SYNC'),
        'entity_type': entityType,
        'entity_id': normalizedEntityId,
        'action': action,
        'payload': jsonEncode(normalizedPayload),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      },
    );

    unawaited(SyncManager.instance.processQueue());
  }

  static Future<void> enqueueCustomerUpsert({
    required String customerId,
    required Map<String, dynamic> payload,
    required bool isUpdate,
  }) async {
    await enqueueSync(
      entityType: 'customers',
      entityId: customerId,
      action: isUpdate ? 'update' : 'create',
      payload: payload,
    );
  }

  static Future<void> enqueueCustomerDelete({
    required String customerId,
  }) async {
    await enqueueSync(
      entityType: 'customers',
      entityId: customerId,
      action: 'delete',
      payload: {'id': customerId},
    );
  }

  static Future<void> enqueueInvoiceUpsert({
    required String invoiceId,
    required Map<String, dynamic> payload,
    required bool isUpdate,
  }) async {
    await enqueueSync(
      entityType: 'invoices',
      entityId: invoiceId,
      action: isUpdate ? 'update' : 'create',
      payload: payload,
    );
  }

  static Future<void> enqueueInvoiceDelete({
    required String invoiceId,
  }) async {
    await enqueueSync(
      entityType: 'invoices',
      entityId: invoiceId,
      action: 'delete',
      payload: {'id': invoiceId},
    );
  }

  static Future<void> addToSyncQueue({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    await enqueueSync(
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
    );
  }

  static Future<Map<String, dynamic>?> getBusinessProfile(String businessId) async {
    final db = await database();
    final rows = await db.query(
      'business_profile',
      where: 'businessId = ?',
      whereArgs: [businessId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return {
        'id': '1',
        'businessId': businessId,
        'business_name': '',
        'trade_name': '',
        'logo_path': '',
        'phone': '',
        'whatsapp': '',
        'email': '',
        'address': '',
        'tax_number': '',
        'registration_number': '',
        'default_invoice_notes': '',
        'default_quotation_notes': '',
        'payment_terms_footer': '',
        'branch_id': null,
      };
    }
    return rows.first;
  }

  static Future<void> saveBusinessProfile(Map<String, dynamic> data) async {
    final db = await database();
    final businessId = data['businessId']?.toString() ?? '';
    final payload = {
      'id': '1',
      'businessId': businessId,
      'business_name': data['business_name']?.toString().trim() ?? '',
      'trade_name': data['trade_name']?.toString().trim(),
      'logo_path': data['logo_path']?.toString().trim(),
      'phone': data['phone']?.toString().trim(),
      'whatsapp': data['whatsapp']?.toString().trim(),
      'email': data['email']?.toString().trim(),
      'address': data['address']?.toString().trim(),
      'tax_number': data['tax_number']?.toString().trim(),
      'registration_number': data['registration_number']?.toString().trim(),
      'default_invoice_notes': data['default_invoice_notes']?.toString().trim(),
      'default_quotation_notes':
          data['default_quotation_notes']?.toString().trim(),
      'payment_terms_footer': data['payment_terms_footer']?.toString().trim(),
      'branch_id': data['branch_id']?.toString().trim(),
    };
    await db.insert(
      'business_profile',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await CloudSyncService.instance.upsertBusinessProfile(_withOwner(payload));
  }

  static Future<List<Map<String, dynamic>>> getQuotations(String businessId) async {
    final db = await database();
    return db.rawQuery('''
      SELECT q.*, c.name AS customer_name
      FROM quotations q
      LEFT JOIN customers c ON q.customer_id = c.id
      WHERE q.businessId = ?
      ORDER BY q.issue_date DESC, q.quotation_number DESC
    ''', [businessId]);
  }

  static Future<List<Map<String, dynamic>>> getQuotationItems(
    String businessId,
    String quotationId,
  ) async {
    final db = await database();
    return db.query(
      'quotation_items',
      where: 'quotation_id = ? AND businessId = ?',
      whereArgs: [quotationId, businessId],
      orderBy: 'id ASC',
    );
  }

  static Future<Map<String, dynamic>?> getQuotationById(String businessId, String quotationId) async {
    final db = await database();
    final rows = await db.rawQuery(
      '''
      SELECT q.*, c.name AS customer_name
      FROM quotations q
      LEFT JOIN customers c ON q.customer_id = c.id AND q.businessId = c.businessId
      WHERE q.id = ? AND q.businessId = ?
      LIMIT 1
      ''',
      [quotationId, businessId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<String> createQuotation({
    required String businessId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String status = 'draft',
    String? issueDate,
    String? expiryDate,
    String? notes,
    String? createdBy,
    String? branchId,
    String? currencyCode,
  }) async {
    if (items.isEmpty) {
      throw Exception('يجب إضافة بند واحد على الأقل.');
    }

    final db = await database();
    final quotationId = _newTextId('QT');
    late final String quotationNumber;
    final createdAt = issueDate ?? DateTime.now().toIso8601String();
    final normalizedItems = _normalizeDocumentItems(items);
    if (normalizedItems.isEmpty) {
      throw Exception('بنود العرض غير صالحة.');
    }
    final subtotal = normalizedItems.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['line_total']),
    );

    final normalizedCurrencyCode = AppCurrency.sanitizeLabel(currencyCode);

    await db.transaction((txn) async {
      quotationNumber = await _nextDocumentNumber(txn, prefix: 'QT');
      await txn.insert('quotations', {
        'id': quotationId,
        'businessId': businessId,
        'quotation_number': quotationNumber,
        'customer_id': customerId,
        'status': status,
        'issue_date': createdAt,
        'expiry_date': expiryDate,
        'subtotal': subtotal,
        'total': subtotal,
        'notes': notes?.trim(),
        'currency_code': normalizedCurrencyCode,
        'created_by': createdBy,
        'branch_id': branchId,
        'converted_invoice_id': null,
      });

      for (final item in normalizedItems) {
        await txn.insert('quotation_items', {
          'businessId': businessId,
          'quotation_id': quotationId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'line_total': item['line_total'],
        });
      }
    });

    final quotationPayload = {
      'id': quotationId,
      'quotation_number': quotationNumber,
      'customer_id': customerId,
      'status': status,
      'issue_date': createdAt,
      'expiry_date': expiryDate,
      'subtotal': subtotal,
      'total': subtotal,
      'notes': notes?.trim(),
      'currency_code': normalizedCurrencyCode,
      'created_by': createdBy,
      'branch_id': branchId,
      'converted_invoice_id': null,
      'items': normalizedItems,
    };

    await CloudSyncService.instance.upsertQuotation(
      _withOwner(quotationPayload),
      items: _withOwnerList(normalizedItems),
    );

    return quotationId;
  }

  static Future<List<Map<String, dynamic>>> getInvoices(String businessId) async {
    final db = await database();
    return db.rawQuery('''
      SELECT i.*, c.name AS customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.businessId = ?
      ORDER BY i.issue_date DESC, i.invoice_number DESC
    ''', [businessId]);
  }

  static Future<List<Map<String, dynamic>>> getInvoiceItems(
    String businessId,
    String invoiceId,
  ) async {
    final db = await database();
    return db.query(
      'invoice_items',
      where: 'invoice_id = ? AND businessId = ?',
      whereArgs: [invoiceId, businessId],
      orderBy: 'id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getInvoicePayments(
    String businessId,
    String invoiceId,
  ) async {
    final db = await database();
    return db.query(
      'payments',
      where: 'invoice_id = ? AND businessId = ?',
      whereArgs: [invoiceId, businessId],
      orderBy: 'payment_date DESC',
    );
  }

  static Future<int> updateInvoicePdfPath({
    required String businessId,
    required String invoiceId,
    required String pdfPath,
  }) async {
    final db = await database();
    final result = await db.update(
      'invoices',
      {'pdf_path': pdfPath},
      where: 'id = ? AND businessId = ?',
      whereArgs: [invoiceId, businessId],
    );
    if (result > 0) {
      await CloudSyncService.instance.upsertInvoice(_withOwner({
        'id': invoiceId,
        'businessId': businessId,
        'pdf_path': pdfPath,
      }));
    }
    return result;
  }

  static Future<int> updateQuotationPdfPath({
    required String businessId,
    required String quotationId,
    required String pdfPath,
  }) async {
    final db = await database();
    final result = await db.update(
      'quotations',
      {'pdf_path': pdfPath},
      where: 'id = ? AND businessId = ?',
      whereArgs: [quotationId, businessId],
    );
    if (result > 0) {
      await CloudSyncService.instance.upsertQuotation(_withOwner({
        'id': quotationId,
        'businessId': businessId,
        'pdf_path': pdfPath,
      }));
    }
    return result;
  }

  static Future<Map<String, dynamic>?> getInvoiceById(String businessId, String invoiceId) async {
    final db = await database();
    final rows = await db.rawQuery(
      '''
      SELECT i.*, c.name AS customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id AND i.businessId = c.businessId
      WHERE i.id = ? AND i.businessId = ?
      LIMIT 1
      ''',
      [invoiceId, businessId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<String> createInvoice({
    required String businessId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String status = 'issued',
    String? issueDate,
    String? dueDate,
    String? notes,
    double paidAmount = 0,
    String paymentMethod = 'on_account',
    String? quotationId,
    String? createdBy,
    String? branchId,
    String? currencyCode,
  }) async {
    if (items.isEmpty) {
      throw Exception('يجب إضافة بند واحد على الأقل.');
    }

    final db = await database();
    final invoiceId = _newTextId('INV');
    late final String invoiceNumber;
    final invoiceDate = issueDate ?? DateTime.now().toIso8601String();
    final normalizedItems = _normalizeDocumentItems(items);
    if (normalizedItems.isEmpty) {
      throw Exception('بنود الفاتورة غير صالحة.');
    }
    final subtotal = normalizedItems.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['line_total']),
    );
    final total = subtotal;
    final normalizedPaidAmount = paidAmount.clamp(0, total).toDouble();
    final remainingAmount = (total - normalizedPaidAmount).toDouble();
    final normalizedCurrencyCode = AppCurrency.sanitizeLabel(currencyCode);
    final shouldPostAccounting = status != 'draft';
    final resolvedStatus = shouldPostAccounting
        ? _resolveInvoiceStatus(
            total: total,
            paidAmount: normalizedPaidAmount,
            dueDate: dueDate,
          )
        : 'draft';

    await db.transaction((txn) async {
      invoiceNumber = await _nextDocumentNumber(txn, prefix: 'INV');
      await _ensureDefaultAccounts(txn, businessId);
      await _repairAccountNames(txn, businessId);

      final cashAccountId = await _requireAccountId(
        txn,
        _cashAccountCode,
        businessId,
      );
      final receivablesAccountId = await _requireAccountId(
        txn,
        _receivablesAccountCode,
        businessId,
      );
      final inventoryAccountId = await _requireAccountId(
        txn,
        _inventoryAccountCode,
        businessId,
      );
      final salesAccountId = await _requireAccountId(
        txn,
        _salesAccountCode,
        businessId,
      );
      final cogsAccountId = await _requireAccountId(
        txn,
        _cogsAccountCode,
        businessId,
      );

      double totalCogs = 0;

      for (final item in normalizedItems) {
        final productId = item['product_id']?.toString() ?? '';
        final qty = _toInt(item['quantity']);
        if (productId.isEmpty || qty <= 0) {
          throw Exception('بند الفاتورة غير صالح.');
        }

        final productRows = await txn.query(
          'products',
          where: 'id = ? AND businessId = ?',
          whereArgs: [productId, businessId],
          limit: 1,
        );
        if (productRows.isEmpty) {
          throw Exception('تعذر العثور على أحد الأصناف المرتبطة بالفاتورة.');
        }

        final product = productRows.first;
        final currentQty = _toInt(product['stock_qty']);
        final landedCost = _toDouble(product['purchase_price']) +
            _toDouble(product['extra_costs']);

        if (shouldPostAccounting && currentQty < qty) {
          throw Exception('الكمية المطلوبة في الفاتورة أكبر من المخزون المتاح.');
        }

        final lineCogs = landedCost * qty;
        totalCogs += lineCogs;

        await txn.insert('invoice_items', {
          'businessId': businessId,
          'invoice_id': invoiceId,
          'product_id': productId,
          'product_name': item['product_name'],
          'quantity': qty,
          'unit_price': item['unit_price'],
          'line_total': item['line_total'],
          'landed_cost': landedCost,
        });

        if (shouldPostAccounting) {
          final updatedQty = currentQty - qty;
          await txn.update(
            'products',
            {'stock_qty': updatedQty},
            where: 'id = ? AND businessId = ?',
            whereArgs: [productId, businessId],
          );
          await _recordProductMovement(
            txn,
            businessId: businessId,
            productId: productId,
            movementType: 'invoice',
            quantity: -qty,
            balanceAfter: updatedQty,
            referenceType: 'invoice',
            referenceId: invoiceId,
            notes: 'فاتورة $invoiceNumber - ${item['product_name']}',
          );
        }
      }

      await txn.insert('invoices', {
        'id': invoiceId,
        'businessId': businessId,
        'invoice_number': invoiceNumber,
        'customer_id': customerId,
        'quotation_id': quotationId,
        'status': resolvedStatus,
        'issue_date': invoiceDate,
        'due_date': dueDate,
        'subtotal': subtotal,
        'total': total,
        'paid_amount': normalizedPaidAmount,
        'remaining_amount': remainingAmount,
        'notes': notes?.trim(),
        'currency_code': normalizedCurrencyCode,
        'created_by': createdBy,
        'branch_id': branchId,
        'payment_method': paymentMethod,
        'accounting_posted': shouldPostAccounting ? 1 : 0,
      });

      if (quotationId != null && quotationId.isNotEmpty) {
        await txn.update(
          'quotations',
          {
            'status': 'converted_to_invoice',
            'converted_invoice_id': invoiceId,
          },
          where: 'id = ? AND businessId = ?',
          whereArgs: [quotationId, businessId],
        );
      }

      if (shouldPostAccounting) {
        final descriptionBase = 'فاتورة $invoiceNumber';

        if (normalizedPaidAmount > 0) {
          await _postJournalEntry(
            txn,
            businessId: businessId,
            debitAccountId: cashAccountId,
            creditAccountId: salesAccountId,
            amount: normalizedPaidAmount,
            description: '$descriptionBase - تحصيل فوري',
            date: invoiceDate,
          );
        }

        if (remainingAmount > 0) {
          await _postJournalEntry(
            txn,
            businessId: businessId,
            debitAccountId: receivablesAccountId,
            creditAccountId: salesAccountId,
            amount: remainingAmount,
            description: '$descriptionBase - ذمم مدينة',
            date: invoiceDate,
          );
        }

        if (totalCogs > 0) {
          await _postJournalEntry(
            txn,
            businessId: businessId,
            debitAccountId: cogsAccountId,
            creditAccountId: inventoryAccountId,
            amount: totalCogs,
            description: '$descriptionBase - تكلفة البضاعة المباعة',
            date: invoiceDate,
          );
        }

        if (normalizedPaidAmount > 0) {
          await txn.insert('payments', {
            'id': _newTextId('PAY'),
            'businessId': businessId,
            'invoice_id': invoiceId,
            'customer_id': customerId,
            'amount': normalizedPaidAmount,
            'payment_method': paymentMethod,
            'payment_date': invoiceDate,
            'note': 'دفعة أولية مع الفاتورة',
            'created_by': createdBy,
            'branch_id': branchId,
          });
        }
      }
    });

    final invoiceItems = await getInvoiceItems(invoiceId, businessId);
    final initialPayments = await getInvoicePayments(invoiceId, businessId);
    Map<String, dynamic>? quotationSnapshot;
    List<Map<String, dynamic>> quotationItems = const [];
    if (quotationId != null && quotationId.isNotEmpty) {
      quotationSnapshot = await getQuotationById(quotationId, businessId);
      quotationItems = await getQuotationItems(quotationId, businessId);
    }

    final invoicePayload = {
      'id': invoiceId,
      'businessId': businessId,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'quotation_id': quotationId,
      'status': resolvedStatus,
      'issue_date': invoiceDate,
      'due_date': dueDate,
      'subtotal': subtotal,
      'total': total,
      'paid_amount': normalizedPaidAmount,
      'remaining_amount': remainingAmount,
      'notes': notes?.trim(),
      'currency_code': normalizedCurrencyCode,
      'created_by': createdBy,
      'branch_id': branchId,
      'payment_method': paymentMethod,
      'accounting_posted': shouldPostAccounting ? 1 : 0,
      'items': invoiceItems,
      'payments': initialPayments,
      if (quotationSnapshot != null) 'quotation': quotationSnapshot,
      if (quotationItems.isNotEmpty) 'quotation_items': quotationItems,
    };

    await CloudSyncService.instance.upsertInvoice(_withOwner(invoicePayload));
    await CloudSyncService.instance.upsertInvoiceItems(
      invoiceId,
      _withOwnerList(invoiceItems),
    );
    if (quotationSnapshot != null) {
      await CloudSyncService.instance.upsertQuotation(
        _withOwner(quotationSnapshot),
        items: _withOwnerList(quotationItems),
      );
    }
    for (final payment in initialPayments) {
      await CloudSyncService.instance.upsertPayment(_withOwner(payment));
    }

    return invoiceId;
  }

  static Future<String> addInvoicePayment({
    required String businessId,
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    String? note,
    String? paymentDate,
    String? createdBy,
    String? branchId,
  }) async {
    if (amount <= 0) {
      throw Exception('قيمة الدفعة يجب أن تكون أكبر من صفر.');
    }

    final db = await database();
    final paymentId = _newTextId('PAY');
    final normalizedDate = paymentDate ?? DateTime.now().toIso8601String();
    late double newPaid;
    late double newRemaining;
    late String updatedStatus;

    await db.transaction((txn) async {
      await _ensureDefaultAccounts(txn, businessId);
      await _repairAccountNames(txn, businessId);

      final invoiceRows = await txn.query(
        'invoices',
        where: 'id = ? AND businessId = ?',
        whereArgs: [invoiceId, businessId],
        limit: 1,
      );
      if (invoiceRows.isEmpty) {
        throw Exception('تعذر العثور على الفاتورة المطلوبة.');
      }

      final invoice = invoiceRows.first;
      if ((invoice['status']?.toString() ?? '') == 'draft' ||
          _toInt(invoice['accounting_posted']) != 1) {
        throw Exception('يجب إصدار الفاتورة قبل تسجيل دفعات عليها.');
      }
      final currentRemaining = _toDouble(invoice['remaining_amount']);
      final currentPaid = _toDouble(invoice['paid_amount']);
      if (currentRemaining <= 0) {
        throw Exception('هذه الفاتورة مسددة بالكامل بالفعل.');
      }
      if (amount > currentRemaining) {
        throw Exception('قيمة الدفعة أكبر من الرصيد المتبقي على الفاتورة.');
      }

      final cashAccountId = await _requireAccountId(
        txn,
        _cashAccountCode,
        businessId,
      );
      final receivablesAccountId = await _requireAccountId(
        txn,
        _receivablesAccountCode,
        businessId,
      );

      await txn.insert('payments', {
        'id': paymentId,
        'businessId': businessId,
        'invoice_id': invoiceId,
        'customer_id': invoice['customer_id'],
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_date': normalizedDate,
        'note': note?.trim(),
        'created_by': createdBy,
        'branch_id': branchId,
      });

      newPaid = currentPaid + amount;
      newRemaining = currentRemaining - amount;
      updatedStatus = _resolveInvoiceStatus(
        total: _toDouble(invoice['total']),
        paidAmount: newPaid,
        dueDate: invoice['due_date']?.toString(),
      );
      await txn.update(
        'invoices',
        {
          'paid_amount': newPaid,
          'remaining_amount': newRemaining,
          'status': updatedStatus,
        },
        where: 'id = ? AND businessId = ?',
        whereArgs: [invoiceId, businessId],
      );

      await _postJournalEntry(
        txn,
        businessId: businessId,
        debitAccountId: cashAccountId,
        creditAccountId: receivablesAccountId,
        amount: amount,
        description: 'سداد على الفاتورة ${invoice['invoice_number']}',
        date: normalizedDate,
      );
    });

    final paymentRows = await getInvoicePayments(invoiceId, businessId);
    final paymentPayloads = paymentRows
        .where((row) => row['id']?.toString() == paymentId)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final invoiceUpdatePayload = {
      'id': invoiceId,
      'businessId': businessId,
      'paid_amount': newPaid,
      'remaining_amount': newRemaining,
      'status': updatedStatus,
      'payments': paymentPayloads,
    };

    await CloudSyncService.instance.upsertInvoice(
      _withOwner(invoiceUpdatePayload),
    );
    for (final payment in paymentPayloads) {
      await CloudSyncService.instance.upsertPayment(_withOwner(payment));
    }

    return paymentId;
  }

  static Future<int> deleteInvoice(String businessId, String invoiceId) async {
    final db = await database();
    int deletedCount = 0;

    await db.transaction((txn) async {
      final invoiceRows = await txn.query(
        'invoices',
        where: 'id = ? AND businessId = ?',
        whereArgs: [invoiceId, businessId],
        limit: 1,
      );

      if (invoiceRows.isEmpty) {
        throw Exception('تعذر العثور على الفاتورة المطلوبة.');
      }

      final invoice = invoiceRows.first;
      final quotationId = invoice['quotation_id']?.toString().trim() ?? '';
      final accountingPosted = _toInt(invoice['accounting_posted']);

      if (accountingPosted == 1) {
        throw Exception(
          'لا يمكن حذف فاتورة صادرة أو مرحّلة محاسبيًا حاليًا. '
          'احذف فقط الفواتير المسودة، أو أضف لاحقًا منطق إلغاء/عكس القيد قبل الحذف.',
        );
      }

      await txn.delete(
        'payments',
        where: 'invoice_id = ? AND businessId = ?',
        whereArgs: [invoiceId, businessId],
      );

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      deletedCount = await txn.delete(
        'invoices',
        where: 'id = ? AND businessId = ?',
        whereArgs: [invoiceId, businessId],
      );

      if (quotationId.isNotEmpty) {
        await txn.update(
          'quotations',
          {
            'status': 'draft',
            'converted_invoice_id': null,
          },
          where: 'id = ? AND businessId = ?',
          whereArgs: [quotationId, businessId],
        );
      }
    });

    if (deletedCount > 0) {
      await enqueueInvoiceDelete(invoiceId: invoiceId);
      await CloudSyncService.instance.deleteInvoice(invoiceId);
    }

    return deletedCount;
  }

  static Future<int> deleteQuotation(String businessId, String quotationId) async {
    final db = await database();
    int deletedCount = 0;

    await db.transaction((txn) async {
      final quotationRows = await txn.query(
        'quotations',
        where: 'id = ? AND businessId = ?',
        whereArgs: [quotationId, businessId],
        limit: 1,
      );

      if (quotationRows.isEmpty) {
        throw Exception('تعذر العثور على عرض السعر المطلوب.');
      }

      final quotation = quotationRows.first;
      final convertedInvoiceId =
          quotation['converted_invoice_id']?.toString().trim() ?? '';

      if (convertedInvoiceId.isNotEmpty) {
        final linkedInvoiceRows = await txn.query(
          'invoices',
          where: 'id = ? AND businessId = ?',
          whereArgs: [convertedInvoiceId, businessId],
          limit: 1,
        );

        if (linkedInvoiceRows.isNotEmpty) {
          throw Exception(
            'لا يمكن حذف عرض سعر تم تحويله إلى فاتورة ما دامت الفاتورة المرتبطة موجودة.',
          );
        }
      }

      await txn.delete(
        'quotation_items',
        where: 'quotation_id = ?',
        whereArgs: [quotationId],
      );

      deletedCount = await txn.delete(
        'quotations',
        where: 'id = ? AND businessId = ?',
        whereArgs: [quotationId, businessId],
      );
    });

    if (deletedCount > 0) {
    }

    return deletedCount;
  }

  static Future<Map<String, dynamic>> getCustomerStatement(
    String customerId,
    String businessId,
  ) async {
    final db = await database();
    final customerRows = await db.query(
      'customers',
      where: 'id = ? AND businessId = ?',
      whereArgs: [customerId, businessId],
      limit: 1,
    );
    if (customerRows.isEmpty) {
      throw Exception('تعذر العثور على العميل المطلوب.');
    }

    final invoices = await db.rawQuery(
      '''
      SELECT *
      FROM invoices
      WHERE customer_id = ? AND businessId = ?
      ORDER BY issue_date DESC, invoice_number DESC
      ''',
      [customerId, businessId],
    );

    final payments = await db.rawQuery(
      '''
      SELECT *
      FROM payments
      WHERE customer_id = ? AND businessId = ?
      ORDER BY payment_date DESC
      ''',
      [customerId, businessId],
    );

    final balanceInvoices = invoices.where((row) {
      final status = row['status']?.toString() ?? '';
      return status != 'draft' && status != 'cancelled';
    }).toList();

    final totalInvoiced = balanceInvoices.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['total']),
    );
    final totalPaid = balanceInvoices.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['paid_amount']),
    );
    final totalRemaining = balanceInvoices.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['remaining_amount']),
    );

    return {
      'customer': customerRows.first,
      'invoices': invoices,
      'payments': payments,
      'total_invoiced': totalInvoiced,
      'total_paid': totalPaid,
      'total_remaining': totalRemaining,
    };
  }

  static Future<bool> isLocalBusinessDataEmpty(String businessId) async {
    final db = await database();
    final productCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM products WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    final salesCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sales_records WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    final journalCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM journal_entries WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    final customerCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM customers WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    final invoiceCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM invoices WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    final quotationCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM quotations WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    final paymentCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM payments WHERE businessId = ?',
            [businessId],
          ),
        ) ??
        0;
    return productCount == 0 &&
        salesCount == 0 &&
        journalCount == 0 &&
        customerCount == 0 &&
        invoiceCount == 0 &&
        quotationCount == 0 &&
        paymentCount == 0;
  }

  static Future<int> restoreCloudSnapshotIfLocalEmpty({
    required String businessId,
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> salesRecords,
    required List<Map<String, dynamic>> journalEntries,
  }) async {
    final db = await database();

    return db.transaction((txn) async {
      final productCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM products WHERE businessId = ?',
              [businessId],
            ),
          ) ??
          0;
      final salesCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sales_records WHERE businessId = ?',
              [businessId],
            ),
          ) ??
          0;
      final journalCount = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM journal_entries WHERE businessId = ?',
              [businessId],
            ),
          ) ??
          0;

      if (productCount > 0 || salesCount > 0 || journalCount > 0) {
        throw Exception(
          'الاستعادة من السحابة متاحة فقط عندما تكون البيانات المحلية لهذا النشاط فارغة.',
        );
      }

      await _ensureDefaultAccounts(txn, businessId);
      await _repairAccountNames(txn, businessId);

      for (final account in accounts) {
        await txn.insert(
          'accounts',
          {...Map<String, dynamic>.from(account), 'businessId': businessId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final product in products) {
        final payload = Map<String, dynamic>.from(product)
          ..putIfAbsent('low_stock_threshold', () => 5)
          ..['businessId'] = businessId;
        await txn.insert(
          'products',
          payload,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await _recordProductMovement(
          txn,
          businessId: businessId,
          productId: payload['id'].toString(),
          movementType: 'restore',
          quantity: _toInt(payload['stock_qty']),
          balanceAfter: _toInt(payload['stock_qty']),
          referenceType: 'restore',
          referenceId: payload['id'].toString(),
          notes: 'استعادة من النسخة السحابية',
        );
      }

      for (final row in salesRecords) {
        await txn.insert(
          'sales_records',
          {
            'id': row['id'] is num ? row['id'] : null,
            'businessId': businessId,
            'product_id': row['product_id']?.toString(),
            'product_name': row['product_name']?.toString(),
            'qty': _toInt(row['qty']),
            'customer_name': row['customer_name']?.toString(),
            'sale_note': row['sale_note']?.toString(),
            'currency_code': AppCurrency.sanitizeLabel(
              row['currency_code']?.toString() ??
                  row['sale_currency_code']?.toString(),
            ),
            'selling_price': _toDouble(
              row['selling_price'] ?? row['original_unit_price'],
            ),
            'landed_cost': _toDouble(row['landed_cost']),
            'total_sale': _toDouble(
              row['total_sale'] ?? row['original_total_sale'],
            ),
            'total_profit': _toDouble(row['total_profit']),
            'date': row['date']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in journalEntries) {
        await txn.insert(
          'journal_entries',
          {...Map<String, dynamic>.from(row), 'businessId': businessId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return products.length;
    });
  }

  static Future<void> replaceLocalBusinessCache({
    required String businessId,
    required Map<String, dynamic>? businessProfile,
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> customers,
    required List<Map<String, dynamic>> quotations,
    required List<Map<String, dynamic>> quotationItems,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> invoiceItems,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> salesRecords,
    required List<Map<String, dynamic>> journalEntries,
    required List<Map<String, dynamic>> productMovements,
  }) async {
    final db = await database();

    await db.transaction((txn) async {
      for (final table in const [
        'quotation_items', // Items don't have businessId but are linked to parent
        'invoice_items',   // Items don't have businessId but are linked to parent
      ]) {
        await txn.delete(table);
      }

      for (final table in const [
        'business_profile', // Profile is singleton for the whole app usually, but we might want to scope it if multiple businesses exist.
        // For now, business_profile doesn't have businessId in schema v12.
        'quotations',
        'payments',
        'invoices',
        'customers',
        'product_movements',
        'sales_records',
        'journal_entries',
        'products',
        'accounts',
      ]) {
        if (table == 'business_profile') {
           await txn.delete(table); // Profile is special, usually one per local DB.
        } else {
          await txn.delete(table, where: 'businessId = ?', whereArgs: [businessId]);
        }
      }

      await _ensureDefaultAccounts(txn, businessId);
      await _repairAccountNames(txn, businessId);

      if (businessProfile != null) {
        await txn.insert(
          'business_profile',
          {
            'id': 1,
            'business_name': businessProfile['business_name']?.toString() ?? '',
            'trade_name': businessProfile['trade_name']?.toString(),
            'logo_path': businessProfile['logo_path']?.toString(),
            'phone': businessProfile['phone']?.toString(),
            'whatsapp': businessProfile['whatsapp']?.toString(),
            'email': businessProfile['email']?.toString(),
            'address': businessProfile['address']?.toString(),
            'tax_number': businessProfile['tax_number']?.toString(),
            'registration_number':
                businessProfile['registration_number']?.toString(),
            'default_invoice_notes':
                businessProfile['default_invoice_notes']?.toString(),
            'default_quotation_notes':
                businessProfile['default_quotation_notes']?.toString(),
            'payment_terms_footer':
                businessProfile['payment_terms_footer']?.toString(),
            'branch_id': businessProfile['branch_id']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final account in accounts) {
        await txn.insert(
          'accounts',
          {...Map<String, dynamic>.from(account), 'businessId': businessId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final product in products) {
        final payload = Map<String, dynamic>.from(product)
          ..putIfAbsent('low_stock_threshold', () => 5)
          ..['businessId'] = businessId;
        await txn.insert(
          'products',
          payload,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final customer in customers) {
        await txn.insert(
          'customers',
          {
            'id': customer['id']?.toString() ?? '',
            'businessId': businessId,
            'name': customer['name']?.toString() ?? '',
            'phone': customer['phone']?.toString(),
            'notes': customer['notes']?.toString(),
            'branch_id': customer['branch_id']?.toString(),
            'created_by': customer['created_by']?.toString(),
            'created_at': customer['created_at']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final quotation in quotations) {
        await txn.insert(
          'quotations',
          {
            'id': quotation['id']?.toString() ?? '',
            'businessId': businessId,
            'quotation_number': quotation['quotation_number']?.toString(),
            'customer_id': quotation['customer_id']?.toString(),
            'status': quotation['status']?.toString(),
            'issue_date': quotation['issue_date']?.toString(),
            'expiry_date': quotation['expiry_date']?.toString(),
            'subtotal': _toDouble(quotation['subtotal']),
            'total': _toDouble(quotation['total']),
            'notes': quotation['notes']?.toString(),
            'currency_code': quotation['currency_code']?.toString(),
            'created_by': quotation['created_by']?.toString(),
            'branch_id': quotation['branch_id']?.toString(),
            'converted_invoice_id':
                quotation['converted_invoice_id']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final item in quotationItems) {
        await txn.insert(
          'quotation_items',
          {
            'id': item['id'] is num ? item['id'] : null,
            'quotation_id': item['quotation_id']?.toString(),
            'product_id': item['product_id']?.toString(),
            'product_name': item['product_name']?.toString(),
            'quantity': _toInt(item['quantity']),
            'unit_price': _toDouble(item['unit_price']),
            'line_total': _toDouble(item['line_total']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final invoice in invoices) {
        await txn.insert(
          'invoices',
          {
            'id': invoice['id']?.toString() ?? '',
            'businessId': businessId,
            'invoice_number': invoice['invoice_number']?.toString(),
            'customer_id': invoice['customer_id']?.toString(),
            'quotation_id': invoice['quotation_id']?.toString(),
            'status': invoice['status']?.toString(),
            'issue_date': invoice['issue_date']?.toString(),
            'due_date': invoice['due_date']?.toString(),
            'subtotal': _toDouble(invoice['subtotal']),
            'total': _toDouble(invoice['total']),
            'paid_amount': _toDouble(invoice['paid_amount']),
            'remaining_amount': _toDouble(invoice['remaining_amount']),
            'notes': invoice['notes']?.toString(),
            'currency_code': invoice['currency_code']?.toString(),
            'created_by': invoice['created_by']?.toString(),
            'branch_id': invoice['branch_id']?.toString(),
            'payment_method': invoice['payment_method']?.toString(),
            'accounting_posted': _toInt(invoice['accounting_posted']),
            'pdf_path': invoice['pdf_path']?.toString(),
            'discount': _toDouble(invoice['discount']),
            'tax': _toDouble(invoice['tax']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final item in invoiceItems) {
        await txn.insert(
          'invoice_items',
          {
            'id': item['id'] is num ? item['id'] : null,
            'invoice_id': item['invoice_id']?.toString(),
            'product_id': item['product_id']?.toString(),
            'product_name': item['product_name']?.toString(),
            'quantity': _toInt(item['quantity']),
            'unit_price': _toDouble(item['unit_price']),
            'line_total': _toDouble(item['line_total']),
            'landed_cost': _toDouble(item['landed_cost']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final payment in payments) {
        await txn.insert(
          'payments',
          {
            'id': payment['id']?.toString() ?? '',
            'businessId': businessId,
            'invoice_id': payment['invoice_id']?.toString(),
            'customer_id': payment['customer_id']?.toString(),
            'amount': _toDouble(payment['amount']),
            'payment_method': payment['payment_method']?.toString(),
            'payment_date': payment['payment_date']?.toString(),
            'note': payment['note']?.toString(),
            'created_by': payment['created_by']?.toString(),
            'branch_id': payment['branch_id']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in salesRecords) {
        await txn.insert(
          'sales_records',
          {...Map<String, dynamic>.from(row), 'businessId': businessId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in journalEntries) {
        await txn.insert(
          'journal_entries',
          {...Map<String, dynamic>.from(row), 'businessId': businessId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final row in productMovements) {
        await txn.insert(
          'product_movements',
          {
            'id': row['id'] is num ? row['id'] : null,
            'businessId': businessId,
            'product_id': row['product_id']?.toString(),
            'movement_type': row['movement_type']?.toString(),
            'quantity': _toInt(row['quantity']),
            'balance_after': _toInt(row['balance_after']),
            'reference_type': row['reference_type']?.toString(),
            'reference_id': row['reference_id']?.toString(),
            'notes': row['notes']?.toString(),
            'date': row['date']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getProductMovementHistory(
    String businessId,
    String productId,
  ) async {
    final db = await database();
    return db.query(
      'product_movements',
      where: 'product_id = ? AND businessId = ?',
      whereArgs: [productId, businessId],
      orderBy: 'date DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getTrialBalance(String businessId) async {
    final db = await database();
    return db.query(
      'accounts',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'code ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getJournalEntries(String businessId) async {
    final db = await database();
    return db.rawQuery('''
      SELECT j.*, 
             a1.name AS debit_account, 
             a2.name AS credit_account
      FROM journal_entries j
      JOIN accounts a1 ON j.debit_account_id = a1.id
      JOIN accounts a2 ON j.credit_account_id = a2.id
      WHERE j.businessId = ?
      ORDER BY j.date DESC
    ''', [businessId]);
  }

  static Future<List<Map<String, dynamic>>> getSalesRecords(String businessId) async {
    final db = await database();
    return db.query(
      'sales_records',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'date DESC',
    );
  }

  static Future<double> getTotalRealizedProfit(String businessId) async =>
      _singleDouble(
        'SELECT SUM(total_profit) AS total FROM sales_records WHERE businessId = ?',
        whereArgs: [businessId],
      );

  static Future<double> getTotalRealizedSales(String businessId) async =>
      _singleDouble(
        'SELECT SUM(total_sale) AS total FROM sales_records WHERE businessId = ?',
        whereArgs: [businessId],
      );

  static Future<int> getSalesCount(String businessId) async => _singleInt(
        'SELECT COUNT(*) AS count FROM sales_records WHERE businessId = ?',
        whereArgs: [businessId],
      );

  static Future<double> getTotalInventoryValue(String businessId) async =>
      _singleDouble(
        '''
      SELECT SUM((purchase_price + extra_costs) * stock_qty) AS total
      FROM products
      WHERE businessId = ?
    ''',
        whereArgs: [businessId],
      );

  static Future<double> getTotalExpectedRevenue(String businessId) async =>
      _singleDouble(
        '''
      SELECT SUM(selling_price * stock_qty) AS total
      FROM products
      WHERE businessId = ?
    ''',
        whereArgs: [businessId],
      );

  static Future<double> getTotalExpectedProfit(String businessId) async =>
      _singleDouble(
        '''
      SELECT SUM((selling_price - purchase_price - extra_costs) * stock_qty) AS total
      FROM products
      WHERE businessId = ?
    ''',
        whereArgs: [businessId],
      );

  static Future<int> getProductsCount(String businessId) async => _singleInt(
        'SELECT COUNT(*) AS count FROM products WHERE businessId = ?',
        whereArgs: [businessId],
      );

  static Future<int> getTotalStockQty(String businessId) async => _singleInt(
        'SELECT SUM(stock_qty) AS total FROM products WHERE businessId = ?',
        key: 'total',
        whereArgs: [businessId],
      );

  static Future<List<Map<String, dynamic>>> getLowStockProducts(String businessId) async {
    final db = await database();
    return db.rawQuery('''
      SELECT *
      FROM products
      WHERE businessId = ? AND stock_qty <= COALESCE(low_stock_threshold, 5)
      ORDER BY stock_qty ASC, name COLLATE NOCASE ASC
    ''', [businessId]);
  }

  static Future<int> getLowStockCount(String businessId) async {
    final db = await database();
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM products
      WHERE businessId = ? AND stock_qty <= COALESCE(low_stock_threshold, 5)
    ''', [businessId]);
    return _toInt(result.first['count']);
  }

  static Future<int> getProductSalesCount(String businessId, String productId) async {
    final db = await database();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sales_records WHERE product_id = ? AND businessId = ?',
      [productId, businessId],
    );
    return _toInt(result.first['count']);
  }

  static Future<int> getProductSoldQty(String businessId, String productId) async {
    final db = await database();
    final result = await db.rawQuery(
      'SELECT SUM(qty) AS total FROM sales_records WHERE product_id = ? AND businessId = ?',
      [productId, businessId],
    );
    return _toInt(result.first['total']);
  }

  static Future<double> getProductRealizedProfit(
    String businessId,
    String productId,
  ) async {
    final db = await database();
    final result = await db.rawQuery(
      'SELECT SUM(total_profit) AS total FROM sales_records WHERE product_id = ? AND businessId = ?',
      [productId, businessId],
    );
    return _toDouble(result.first['total']);
  }

  static Future<double> getProductRealizedSales(
    String businessId,
    String productId,
  ) async {
    final db = await database();
    final result = await db.rawQuery(
      'SELECT SUM(total_sale) AS total FROM sales_records WHERE product_id = ? AND businessId = ?',
      [productId, businessId],
    );
    return _toDouble(result.first['total']);
  }

  static Future<List<Map<String, dynamic>>> getProductSalesHistory(
    String businessId,
    String productId,
  ) async {
    final db = await database();
    return db.query(
      'sales_records',
      where: 'product_id = ? AND businessId = ?',
      whereArgs: [productId, businessId],
      orderBy: 'date DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getTopSellingProducts(
    String businessId, {
    int limit = 5,
  }) async {
    final db = await database();
    return db.rawQuery('''
      SELECT product_id, product_name, SUM(qty) AS sold_qty,
             SUM(total_sale) AS total_sale, SUM(total_profit) AS total_profit
      FROM sales_records
      WHERE businessId = ?
      GROUP BY product_id, product_name
      ORDER BY sold_qty DESC, total_sale DESC
      LIMIT ?
    ''', [businessId, limit]);
  }

  static List<Map<String, dynamic>> _normalizeDocumentItems(
    List<Map<String, dynamic>> items,
  ) {
    return items.map((item) {
      final quantity = _toInt(item['quantity']);
      final unitPrice = _toDouble(item['unit_price']);
      final lineTotal = _toDouble(item['line_total']) > 0
          ? _toDouble(item['line_total'])
          : quantity * unitPrice;
      return {
        'product_id': item['product_id']?.toString() ?? '',
        'product_name': item['product_name']?.toString() ?? '',
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_total': lineTotal,
      };
    }).where((item) {
      return item['product_id']!.toString().isNotEmpty &&
          _toInt(item['quantity']) > 0 &&
          _toDouble(item['unit_price']) >= 0;
    }).toList();
  }

  static Future<String> _nextDocumentNumber(
    DatabaseExecutor db, {
    required String prefix,
  }) async {
    final today = DateTime.now();
    final datePart =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final counterKey = '$prefix-$datePart';

    final rows = await db.query(
      'document_counters',
      columns: ['last_value'],
      where: 'key = ?',
      whereArgs: [counterKey],
      limit: 1,
    );

    final nextValue = rows.isEmpty ? 1 : _toInt(rows.first['last_value']) + 1;

    if (rows.isEmpty) {
      await db.insert('document_counters', {
        'key': counterKey,
        'last_value': nextValue,
      });
    } else {
      await db.update(
        'document_counters',
        {'last_value': nextValue},
        where: 'key = ?',
        whereArgs: [counterKey],
      );
    }

    return '$prefix-$datePart-${nextValue.toString().padLeft(4, '0')}';
  }

  static Future<void> _createPerformanceIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON invoices(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_issue_date ON invoices(issue_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items(invoice_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_product_id ON invoice_items(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments(invoice_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
    );
  }

  static String _resolveInvoiceStatus({
    required double total,
    required double paidAmount,
    String? dueDate,
  }) {
    final remaining = total - paidAmount;
    if (paidAmount <= 0) {
      if (dueDate != null && dueDate.isNotEmpty) {
        final due = DateTime.tryParse(dueDate)?.toLocal();
        if (due != null && due.isBefore(DateTime.now()) && remaining > 0) {
          return 'overdue';
        }
      }
      return 'issued';
    }
    if (remaining <= 0.009) return 'paid';
    return 'partially_paid';
  }

  static String _newTextId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  static Future<double> _singleDouble(
    String query, {
    List<Object?>? whereArgs,
  }) async {
    final db = await database();
    final result = await db.rawQuery(query, whereArgs);
    if (result.isEmpty) return 0;
    return _toDouble(result.first.values.first);
  }

  static Future<int> _singleInt(
    String query, {
    String key = 'count',
    List<Object?>? whereArgs,
  }) async {
    final db = await database();
    final result = await db.rawQuery(query, whereArgs);
    if (result.isEmpty) return 0;
    return _toInt(result.first[key]);
  }

  static Future<int> _requireAccountId(
    DatabaseExecutor db,
    String code,
    String businessId,
  ) async {
    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'code = ? AND businessId = ?',
      whereArgs: [code, businessId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('تعذر العثور على الحساب المحاسبي $code للمنشأة الحالية.');
    }

    return _toInt(rows.first['id']);
  }

  static Future<int> _postJournalEntry(
    DatabaseExecutor db, {
    required String businessId,
    required int debitAccountId,
    required int creditAccountId,
    required double amount,
    required String description,
    required String date,
  }) async {
    final journalEntryId = await db.insert('journal_entries', {
      'businessId': businessId,
      'debit_account_id': debitAccountId,
      'credit_account_id': creditAccountId,
      'amount': amount,
      'description': description,
      'date': date,
    });

    await db.execute(
      'UPDATE accounts SET balance = balance + ? WHERE id = ? AND businessId = ?',
      [amount, debitAccountId, businessId],
    );
    await db.execute(
      'UPDATE accounts SET balance = balance - ? WHERE id = ? AND businessId = ?',
      [amount, creditAccountId, businessId],
    );

    return journalEntryId;
  }

  static String _buildSaleDescription({
    required String productName,
    String? customerName,
    String? note,
  }) {
    final parts = <String>['بيع الصنف: $productName'];
    if (customerName != null && customerName.isNotEmpty) {
      parts.add('العميل: $customerName');
    }
    if (note != null && note.isNotEmpty) {
      parts.add('ملاحظة: $note');
    }
    return parts.join(' - ');
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static ProductModel productFromMap(Map<String, dynamic> map) => ProductModel.fromMap(map);

  static String _requireCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً قبل مزامنة البيانات.');
    }
    return user.uid;
  }

  static Map<String, dynamic> _withOwner(Map<String, dynamic> payload) {
    final userId = _requireCurrentUserId();
    return {
      ...Map<String, dynamic>.from(payload),
      'ownerId': userId,
      'owner_id': userId,
      'user_id': userId,
    };
  }

  static List<Map<String, dynamic>> _withOwnerList(
    List<Map<String, dynamic>> payloads,
  ) {
    return payloads.map(_withOwner).toList();
  }
}
