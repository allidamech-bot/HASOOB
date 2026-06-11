import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:hasoob_app/features/ai_accountant/data/tools/financial_tools.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const businessId = 'qa-tools-business';
  late FinancialTools tools;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final tempDir = await Directory.systemTemp.createTemp('hasoob_ai_tools_');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    tools = FinancialTools();
    final db = await DBHelper.database();
    for (final table in [
      'journal_entries',
      'invoice_items',
      'invoices',
      'customers',
      'accounts',
    ]) {
      await db.delete(table);
    }
  });

  test('expenses prefer entry_type source_type metadata', () async {
    final db = await DBHelper.database();
    await db.insert('journal_entries', {
      'businessId': businessId,
      'amount': 42.0,
      'description': 'Vendor charge',
      'date': '2026-01-01T00:00:00.000',
      'entry_type': 'expense',
      'source_type': 'ai_accountant',
    });
    await db.insert('journal_entries', {
      'businessId': businessId,
      'amount': 99.0,
      'description': 'expense word but classified as sale',
      'date': '2026-01-02T00:00:00.000',
      'entry_type': 'sale',
      'source_type': 'ai_accountant',
    });

    final result = await tools.getExpenses(businessId: businessId);
    final data = result.data as Map<String, dynamic>;

    expect(result.success, isTrue);
    expect(data['total'], 42.0);
    expect(data['count'], 1);
  });

  test('legacy text-matching fallback still works for old rows', () async {
    final db = await DBHelper.database();
    await db.insert('journal_entries', {
      'businessId': businessId,
      'amount': 18.0,
      'description': 'legacy office expense',
      'date': '2026-01-01T00:00:00.000',
    });

    final result = await tools.getExpenses(businessId: businessId);
    final data = result.data as Map<String, dynamic>;

    expect(result.success, isTrue);
    expect(data['total'], 18.0);
    expect(data['count'], 1);
  });

  test('getInvoices reads totals correctly', () async {
    final db = await DBHelper.database();
    await db.insert('invoices', {
      'id': 'inv-1',
      'businessId': businessId,
      'invoice_number': 'INV-1',
      'customer_id': 'c-1',
      'status': 'issued',
      'issue_date': '2026-01-01T00:00:00.000',
      'total': 100.0,
      'paid_amount': 40.0,
      'remaining_amount': 60.0,
    });
    await db.insert('invoices', {
      'id': 'inv-2',
      'businessId': businessId,
      'invoice_number': 'INV-2',
      'customer_id': 'c-1',
      'status': 'issued',
      'issue_date': '2026-01-02T00:00:00.000',
      'total': 25.0,
      'paid_amount': 5.0,
      'remaining_amount': 20.0,
    });

    final result = await tools.getInvoices(businessId: businessId);
    final data = result.data as Map<String, dynamic>;

    expect(result.success, isTrue);
    expect(data['totalAmount'], 125.0);
    expect(data['totalPaid'], 45.0);
    expect(data['outstanding'], 80.0);
    expect(data['count'], 2);
  });

  test('getCustomers reads outstanding balances correctly', () async {
    final db = await DBHelper.database();
    await db.insert('customers', {
      'id': 'c-1',
      'businessId': businessId,
      'name': 'Customer One',
      'created_at': '2026-01-01T00:00:00.000',
    });
    await db.insert('customers', {
      'id': 'c-2',
      'businessId': businessId,
      'name': 'Customer Two',
      'created_at': '2026-01-01T00:00:00.000',
    });
    await db.insert('invoices', {
      'id': 'inv-1',
      'businessId': businessId,
      'invoice_number': 'INV-1',
      'customer_id': 'c-1',
      'status': 'issued',
      'issue_date': '2026-01-01T00:00:00.000',
      'total': 100.0,
      'paid_amount': 40.0,
      'remaining_amount': 60.0,
    });
    await db.insert('invoices', {
      'id': 'inv-2',
      'businessId': businessId,
      'invoice_number': 'INV-2',
      'customer_id': 'c-2',
      'status': 'draft',
      'issue_date': '2026-01-01T00:00:00.000',
      'total': 80.0,
      'paid_amount': 0.0,
      'remaining_amount': 80.0,
    });

    final result = await tools.getCustomers(businessId: businessId);
    final data = result.data as Map<String, dynamic>;
    final records = data['records'] as List<Map<String, dynamic>>;

    expect(result.success, isTrue);
    expect(data['totalOutstanding'], 60.0);
    expect(
        records.firstWhere((row) => row['id'] == 'c-1')['outstanding_balance'],
        60.0);
    expect(
        records.firstWhere((row) => row['id'] == 'c-2')['outstanding_balance'],
        0.0);
  });
}
