import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:hasoob_app/features/ai_accountant/data/models/ai_proposal_model.dart';
import 'package:hasoob_app/features/ai_accountant/domain/services/proposal_execution_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const businessId = 'qa-business';
  late ProposalExecutionEngine engine;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir = await Directory.systemTemp.createTemp('hasoob_ai_engine_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    engine = ProposalExecutionEngine();
    final db = await DBHelper.database();
    for (final table in [
      'sync_operations',
      'pricing_simulations',
      'journal_entries',
      'invoice_items',
      'invoices',
      'product_movements',
      'products',
      'customers',
      'accounts',
    ]) {
      await db.delete(table);
    }
    await db.execute('DROP TRIGGER IF EXISTS fail_ai_journal');
  });

  Future<void> seedAccounts({List<String>? omit}) async {
    final db = await DBHelper.database();
    final omitted = (omit ?? const <String>[]).toSet();
    final accounts = [
      {'code': '102', 'name': 'Inventory', 'category': 'asset'},
      {'code': '201', 'name': 'Payables', 'category': 'liability'},
      {'code': '103', 'name': 'Receivables', 'category': 'asset'},
      {'code': '401', 'name': 'Sales', 'category': 'revenue'},
      {'code': '501', 'name': 'COGS', 'category': 'expense'},
    ];
    for (final account in accounts) {
      if (omitted.contains(account['code'])) continue;
      await db.insert('accounts', {
        'businessId': businessId,
        'code': account['code'],
        'name': account['name'],
        'category': account['category'],
        'balance': 0.0,
      });
    }
  }

  Future<void> seedProduct({
    required String id,
    required String name,
    int stock = 10,
    double purchasePrice = 5,
    double sellingPrice = 12,
  }) async {
    final db = await DBHelper.database();
    await db.insert('products', {
      'id': id,
      'businessId': businessId,
      'name': name,
      'unit': 'carton',
      'purchase_price': purchasePrice,
      'extra_costs': 0.0,
      'selling_price': sellingPrice,
      'stock_qty': stock,
      'low_stock_threshold': 1,
    });
  }

  Future<int> count(String table) async {
    final db = await DBHelper.database();
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    return rows.first['total'] as int? ?? 0;
  }

  Future<int> stockOf(String productId) async {
    final db = await DBHelper.database();
    final rows = await db.query(
      'products',
      columns: ['stock_qty'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.first['stock_qty'] as int;
  }

  test('purchase with explicit productId creates product and journal entry',
      () async {
    await seedAccounts();

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'purchase',
        explanation: 'شراء اختبار',
        confidenceScore: 0.9,
        inventoryPayload: {
          'productId': 'p-explicit',
          'name': 'Explicit Product',
          'quantity': 4,
          'costPrice': 7.5,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(await count('products'), 1);
    expect(await count('journal_entries'), 1);
    expect(await count('sync_operations'), greaterThanOrEqualTo(2));
    expect((result.data as Map)['auditLog']['status'], 'failed');
  });

  test('purchase with strong single normalized name match updates product',
      () async {
    await seedAccounts();
    await seedProduct(id: 'p-name', name: 'Widget A', stock: 3);

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'purchase',
        explanation: 'توريد مطابق بالاسم',
        confidenceScore: 0.9,
        inventoryPayload: {
          'name': '  Widget A  ',
          'quantity': 2,
          'costPrice': 6,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(await stockOf('p-name'), 5);
    expect(await count('journal_entries'), 1);
  });

  test(
      'ambiguous product name returns requiresUserConfirmation and performs no DB mutation',
      () async {
    await seedAccounts();
    await seedProduct(id: 'p-1', name: 'Shared Name', stock: 3);
    await seedProduct(id: 'p-2', name: 'Shared Name', stock: 8);

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'purchase',
        explanation: 'توريد غير مؤكد',
        confidenceScore: 0.8,
        inventoryPayload: {
          'name': 'Shared Name',
          'quantity': 2,
          'costPrice': 4,
        },
      ),
    );

    expect(result.success, isFalse);
    expect(result.requiresUserConfirmation, isTrue);
    expect(((result.data as Map)['candidates'] as List), hasLength(2));
    expect(await stockOf('p-1'), 3);
    expect(await stockOf('p-2'), 8);
    expect(await count('journal_entries'), 0);
    expect(await count('sync_operations'), 0);
  });

  test('sale with valid stock creates invoice and journal entries', () async {
    await seedAccounts();
    await seedProduct(id: 'p-sale', name: 'Sale Product', stock: 5);

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'sale',
        explanation: 'بيع اختبار',
        confidenceScore: 0.9,
        inventoryPayload: {
          'productId': 'p-sale',
          'quantity': 2,
        },
        financialPayload: {
          'totalAmount': 30.0,
          'unitPrice': 15.0,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(await stockOf('p-sale'), 3);
    expect(await count('invoices'), 1);
    expect(await count('invoice_items'), 1);
    expect(await count('journal_entries'), 2);
  });

  test('sale with insufficient stock fails safely without partial DB writes',
      () async {
    await seedAccounts();
    await seedProduct(id: 'p-low', name: 'Low Stock', stock: 1);

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'sale',
        explanation: 'بيع أكبر من المخزون',
        confidenceScore: 0.9,
        inventoryPayload: {
          'productId': 'p-low',
          'quantity': 2,
        },
        financialPayload: {
          'totalAmount': 20.0,
          'unitPrice': 10.0,
        },
      ),
    );

    expect(result.success, isFalse);
    expect(await stockOf('p-low'), 1);
    expect(await count('invoices'), 0);
    expect(await count('journal_entries'), 0);
    expect(await count('sync_operations'), 0);
  });

  test('pricing simulation is persisted', () async {
    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'pricing_simulation',
        explanation: 'محاكاة تسعير',
        confidenceScore: 0.9,
        pricingPayload: {
          'itemBasePrice': 10.0,
          'landedCostPerUnit': 13.0,
          'shippingCost': 100.0,
          'customsCost': 30.0,
          'targetMarginPercentage': 25.0,
          'destination': 'Riyadh',
          'suggestedPricePerUnit': 17.34,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(await count('pricing_simulations'), 1);
    expect(await count('sync_operations'), 1);
  });

  test('missing chart accounts returns setup guard without DB mutation',
      () async {
    await seedAccounts(omit: ['201']);

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'purchase',
        explanation: 'شراء بدون حسابات مكتملة',
        confidenceScore: 0.9,
        inventoryPayload: {
          'productId': 'p-missing-account',
          'name': 'Missing Account Product',
          'quantity': 1,
          'costPrice': 4,
        },
      ),
    );

    expect(result.success, isFalse);
    expect(result.requiresUserConfirmation, isTrue);
    expect((result.data as Map)['reason'], 'missing_chart_accounts');
    expect(await count('products'), 0);
    expect(await count('journal_entries'), 0);
    expect(await count('sync_operations'), 0);
  });

  test('Firestore audit failure does not fail local transaction', () async {
    await seedAccounts();

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'purchase',
        explanation: 'شراء مع فشل تدقيق بعيد',
        confidenceScore: 0.9,
        inventoryPayload: {
          'productId': 'p-audit',
          'name': 'Audit Product',
          'quantity': 1,
          'costPrice': 4,
        },
      ),
    );

    expect(result.success, isTrue);
    expect((result.data as Map)['auditLog']['status'], 'failed');
    expect(await count('products'), 1);
    expect(await count('journal_entries'), 1);
  });

  test('transaction rollback prevents invoice journal product inconsistency',
      () async {
    await seedAccounts();
    await seedProduct(id: 'p-rollback', name: 'Rollback Product', stock: 5);
    final db = await DBHelper.database();
    await db.execute('''
      CREATE TRIGGER fail_ai_journal
      AFTER INSERT ON journal_entries
      WHEN NEW.source_type = 'ai_accountant'
      BEGIN
        SELECT RAISE(FAIL, 'forced journal failure');
      END;
    ''');

    final result = await engine.executeProposal(
      businessId: businessId,
      proposal: AiProposalModel(
        actionType: 'sale',
        explanation: 'بيع مع فشل قسري',
        confidenceScore: 0.9,
        inventoryPayload: {
          'productId': 'p-rollback',
          'quantity': 2,
        },
        financialPayload: {
          'totalAmount': 30.0,
          'unitPrice': 15.0,
        },
      ),
    );

    expect(result.success, isFalse);
    expect(await stockOf('p-rollback'), 5);
    expect(await count('invoices'), 0);
    expect(await count('invoice_items'), 0);
    expect(await count('journal_entries'), 0);
  });
}
