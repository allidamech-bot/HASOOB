import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hasoob_app/core/services/branch_context.dart';
import 'package:hasoob_app/data/models/branch_model.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Financial Integrity Guardrails Tests', () {
    late Database db;
    const String testBusinessId = 'TEST-BIZ-GUARDRAILS';

    setUp(() async {
      BranchContext().switchBranch(BranchModel(
        id: 'TEST-BRANCH',
        businessId: testBusinessId,
        name: 'Test Branch',
        code: 'TEST',
        isMainBranch: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      db = await DBHelper.database();
      await _resetDatabase(db, testBusinessId);
    });

    tearDown(() async {
      await db.close();
    });

    test('deleting a customer with invoice is blocked', () async {
      await db.insert('customers', {
        'id': 'CUS-INV-REF',
        'businessId': testBusinessId,
        'name': 'عميل بفاتورة',
        'branch_id': 'TEST-BRANCH',
      });

      await db.insert('invoices', {
        'id': 'INV-CUS-REF',
        'businessId': testBusinessId,
        'invoice_number': 'INV-001',
        'customer_id': 'CUS-INV-REF',
        'status': 'issued',
        'total': 100,
        'paid_amount': 0,
        'remaining_amount': 100,
        'branch_id': 'TEST-BRANCH',
      });

      expect(
        () => DBHelper.deleteCustomer(testBusinessId, 'CUS-INV-REF'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting a customer with payment is blocked', () async {
      await db.insert('customers', {
        'id': 'CUS-PAY-REF',
        'businessId': testBusinessId,
        'name': 'عميل بدفعة',
        'branch_id': 'TEST-BRANCH',
      });

      await db.insert('payments', {
        'id': 'PAY-CUS-REF',
        'businessId': testBusinessId,
        'invoice_id': 'INV-DUMMY',
        'customer_id': 'CUS-PAY-REF',
        'amount': 50,
        'branch_id': 'TEST-BRANCH',
      });

      expect(
        () => DBHelper.deleteCustomer(testBusinessId, 'CUS-PAY-REF'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting a customer with quotation is blocked', () async {
      await db.insert('customers', {
        'id': 'CUS-QT-REF',
        'businessId': testBusinessId,
        'name': 'عميل بعرض سعر',
        'branch_id': 'TEST-BRANCH',
      });

      await db.insert('quotations', {
        'id': 'QT-CUS-REF',
        'businessId': testBusinessId,
        'quotation_number': 'QT-001',
        'customer_id': 'CUS-QT-REF',
        'status': 'draft',
        'total': 100,
        'branch_id': 'TEST-BRANCH',
      });

      expect(
        () => DBHelper.deleteCustomer(testBusinessId, 'CUS-QT-REF'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting unreferenced customer works', () async {
      await db.insert('customers', {
        'id': 'CUS-UNREF',
        'businessId': testBusinessId,
        'name': 'عميل غير مرتبط',
        'branch_id': 'TEST-BRANCH',
      });

      final result =
          await DBHelper.deleteCustomer(testBusinessId, 'CUS-UNREF');
      expect(result, equals(1));
    });

    test('deleting product with stock is blocked', () async {
      await db.insert('products', {
        'id': 'PROD-STOCK',
        'businessId': testBusinessId,
        'name': 'صنف بالمخزون',
        'stock_qty': 5,
        'branch_id': 'TEST-BRANCH',
      });

      expect(
        () => DBHelper.deleteProduct(testBusinessId, 'PROD-STOCK'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting product with sales is blocked', () async {
      await db.insert('products', {
        'id': 'PROD-SALES',
        'businessId': testBusinessId,
        'name': 'صنف بمبيعات',
        'stock_qty': 0,
        'branch_id': 'TEST-BRANCH',
      });

      await db.insert('sales_records', {
        'businessId': testBusinessId,
        'product_id': 'PROD-SALES',
        'product_name': 'صنف بمبيعات',
        'qty': 1,
        'selling_price': 10,
        'landed_cost': 5,
        'total_sale': 10,
        'total_profit': 5,
        'branch_id': 'TEST-BRANCH',
        'date': DateTime.now().toIso8601String(),
      });

      expect(
        () => DBHelper.deleteProduct(testBusinessId, 'PROD-SALES'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting product with invoice_items is blocked', () async {
      await db.insert('products', {
        'id': 'PROD-INV-ITEM',
        'businessId': testBusinessId,
        'name': 'صنف ببند فاتورة',
        'stock_qty': 0,
        'branch_id': 'TEST-BRANCH',
      });

      await db.insert('invoice_items', {
        'businessId': testBusinessId,
        'invoice_id': 'INV-TEST',
        'product_id': 'PROD-INV-ITEM',
        'product_name': 'صنف ببند فاتورة',
        'quantity': 1,
        'unit_price': 10,
        'line_total': 10,
      });

      expect(
        () => DBHelper.deleteProduct(testBusinessId, 'PROD-INV-ITEM'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting product with quotation_items is blocked', () async {
      await db.insert('products', {
        'id': 'PROD-QT-ITEM',
        'businessId': testBusinessId,
        'name': 'صنف ببند عرض سعر',
        'stock_qty': 0,
        'branch_id': 'TEST-BRANCH',
      });

      await db.insert('quotation_items', {
        'businessId': testBusinessId,
        'quotation_id': 'QT-TEST',
        'product_id': 'PROD-QT-ITEM',
        'product_name': 'صنف ببند عرض سعر',
        'quantity': 1,
        'unit_price': 10,
        'line_total': 10,
      });

      expect(
        () => DBHelper.deleteProduct(testBusinessId, 'PROD-QT-ITEM'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting unreferenced zero-stock product still works', () async {
      await db.insert('products', {
        'id': 'PROD-UNREF',
        'businessId': testBusinessId,
        'name': 'صنف غير مرتبط',
        'stock_qty': 0,
        'branch_id': 'TEST-BRANCH',
      });

      final result = await DBHelper.deleteProduct(testBusinessId, 'PROD-UNREF');
      expect(result, equals(1));
    });

    test('integrity helper detects orphan invoice_item', () async {
      await db.insert('invoice_items', {
        'businessId': testBusinessId,
        'invoice_id': 'INV-ORPHAN',
        'product_id': 'PROD-EXISTING',
        'product_name': 'منتج',
        'quantity': 1,
        'unit_price': 10,
        'line_total': 10,
      });

      final report =
          await DBHelper.getFinancialIntegrityReport(testBusinessId);

      expect(
        report['orphan_invoice_items'],
        greaterThan(0),
      );
    });

    test('integrity helper detects orphan payment missing invoice', () async {
      await db.insert('payments', {
        'id': 'PAY-ORPHAN',
        'businessId': testBusinessId,
        'invoice_id': 'INV-NONEXISTENT',
        'customer_id': 'CUS-TEST',
        'amount': 50,
        'branch_id': 'TEST-BRANCH',
      });

      final report =
          await DBHelper.getFinancialIntegrityReport(testBusinessId);

      expect(
        report['orphan_payments_missing_invoice'],
        greaterThan(0),
      );
    });
  });
}

Future<void> _resetDatabase(Database db, String businessId) async {
  await db.delete('payments', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('invoices', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('quotations', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('customers', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('products', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('invoice_items', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('quotation_items', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete('sales_records', where: 'businessId = ?', whereArgs: [businessId]);
  await db.delete(
      'product_movements', where: 'businessId = ?', whereArgs: [businessId]);
}