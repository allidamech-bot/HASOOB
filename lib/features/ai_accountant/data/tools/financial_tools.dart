import 'package:flutter/foundation.dart';
import '../../../../data/database/database_helper.dart';

class FinancialToolResult {
  final bool success;
  final String? error;
  final dynamic data;

  const FinancialToolResult({required this.success, this.error, this.data});

  factory FinancialToolResult.success(dynamic data) =>
      FinancialToolResult(success: true, data: data);
  factory FinancialToolResult.failure(String error) =>
      FinancialToolResult(success: false, error: error);
}

class FinancialTools {
  Future<FinancialToolResult> getIncome({
    required String businessId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      final salesRecords = await DBHelper.getSalesRecords(businessId);

      var filtered = salesRecords;
      if (from != null) {
        filtered = filtered.where((r) {
          final date = DateTime.tryParse(r['date']?.toString() ?? '');
          return date != null && !date.isBefore(from);
        }).toList();
      }
      if (to != null) {
        filtered = filtered.where((r) {
          final date = DateTime.tryParse(r['date']?.toString() ?? '');
          return date != null && !date.isAfter(to);
        }).toList();
      }
      if (limit > 0) {
        filtered = filtered.take(limit).toList();
      }

      final total = filtered.fold<double>(
          0, (sum, r) => sum + _toDouble(r['total_sale']));
      final profit = filtered.fold<double>(
          0, (sum, r) => sum + _toDouble(r['total_profit']));

      return FinancialToolResult.success({
        'records': filtered,
        'total': total,
        'profit': profit,
        'count': filtered.length,
      });
    } catch (e) {
      debugPrint('[FinancialTools] getIncome error: $e');
      return FinancialToolResult.failure('Failed to retrieve income data: $e');
    }
  }

  Future<FinancialToolResult> getExpenses({
    required String businessId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      // Expenses are tracked via journal entries with negative impacts on cash
      final db = await DBHelper.database();
      final journalEntries = await db.query(
        'journal_entries',
        where: '''
          businessId = ? AND (
            entry_type IN (?, ?, ?) OR
            source_type = ? OR
            (entry_type IS NULL AND (description LIKE ? OR description LIKE ?))
          )
        ''',
        whereArgs: [
          businessId,
          'expense',
          'cost_of_goods_sold',
          'ai_expense',
          'expense',
          '%مصروف%',
          '%expense%',
        ],
        orderBy: 'date DESC',
        limit: limit,
      );

      double total = 0;
      final expenseRecords = <Map<String, dynamic>>[];

      for (final entry in journalEntries) {
        final amount = _toDouble(entry['amount']);
        if (amount > 0) {
          total += amount;
          expenseRecords.add(entry);
        }
      }

      return FinancialToolResult.success({
        'records': expenseRecords,
        'total': total,
        'count': expenseRecords.length,
      });
    } catch (e) {
      debugPrint('[FinancialTools] getExpenses error: $e');
      // Fallback: return empty result
      return FinancialToolResult.success({
        'records': <Map<String, dynamic>>[],
        'total': 0.0,
        'count': 0,
      });
    }
  }

  Future<FinancialToolResult> getInvoices({
    required String businessId,
    String? status,
    int limit = 100,
  }) async {
    try {
      final invoices = await DBHelper.getInvoices(businessId);

      var filtered = invoices;
      if (status != null) {
        filtered = filtered
            .where((i) => (i['status']?.toString() ?? '') == status)
            .toList();
      }
      if (limit > 0) {
        filtered = filtered.take(limit).toList();
      }

// DBHelper.getInvoices returns: total (not total_amount), paid_amount, remaining_amount
      final totalAmount =
          filtered.fold<double>(0, (sum, i) => sum + _toDouble(i['total']));
      final totalPaid = filtered.fold<double>(
          0, (sum, i) => sum + _toDouble(i['paid_amount']));

      return FinancialToolResult.success({
        'records': filtered,
        'totalAmount': totalAmount,
        'totalPaid': totalPaid,
        'outstanding': totalAmount - totalPaid,
        'count': filtered.length,
      });
    } catch (e) {
      debugPrint('[FinancialTools] getInvoices error: $e');
      return FinancialToolResult.failure('Failed to retrieve invoice data: $e');
    }
  }

  Future<FinancialToolResult> getCustomers({
    required String businessId,
    String? searchQuery,
    int limit = 100,
  }) async {
    try {
      var customers = await DBHelper.getCustomers(businessId);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        customers = customers
            .where((c) =>
                (c['name']?.toString().toLowerCase() ?? '').contains(query) ||
                (c['phone']?.toString().toLowerCase() ?? '').contains(query))
            .toList();
      }

      if (limit > 0) {
        customers = customers.take(limit).toList();
      }

      final totalOutstanding = customers.fold<double>(
          0, (sum, c) => sum + _toDouble(c['outstanding_balance']));

      return FinancialToolResult.success({
        'records': customers,
        'totalOutstanding': totalOutstanding,
        'count': customers.length,
      });
    } catch (e) {
      debugPrint('[FinancialTools] getCustomers error: $e');
      return FinancialToolResult.failure(
          'Failed to retrieve customer data: $e');
    }
  }

  Future<FinancialToolResult> getProducts({
    required String businessId,
    String? searchQuery,
    bool lowStockOnly = false,
    int limit = 100,
  }) async {
    try {
      var products = await DBHelper.getProducts(businessId);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        products = products
            .where((p) =>
                (p['name']?.toString().toLowerCase() ?? '').contains(query))
            .toList();
      }

      if (lowStockOnly) {
        products = products.where((p) {
          // DB returns low_stock_threshold and stock_qty
          final threshold = _toInt(p['low_stock_threshold']);
          final stock = _toInt(p['stock_qty']);
          return threshold > 0 && stock <= threshold;
        }).toList();
      }

      if (limit > 0) {
        products = products.take(limit).toList();
      }

      // Calculate total value from products (DB returns purchase_price, stock_qty)
      final totalValue = products.fold<double>(0, (sum, p) {
        final landedCost =
            _toDouble(p['purchase_price']) + _toDouble(p['extra_costs']);
        final stock = _toInt(p['stock_qty']);
        return sum + (landedCost * stock);
      });

      return FinancialToolResult.success({
        'records': products,
        'totalValue': totalValue,
        'count': products.length,
      });
    } catch (e) {
      debugPrint('[FinancialTools] getProducts error: $e');
      return FinancialToolResult.failure('Failed to retrieve product data: $e');
    }
  }

  Future<FinancialToolResult> getFinancialSummary({
    required String businessId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final incomeResult =
          await getIncome(businessId: businessId, from: from, to: to);
      final expenseResult =
          await getExpenses(businessId: businessId, from: from, to: to);
      final invoiceResult = await getInvoices(businessId: businessId);

      if (!incomeResult.success ||
          !expenseResult.success ||
          !invoiceResult.success) {
        return FinancialToolResult.failure(
            'Failed to retrieve financial summary');
      }

      final income = incomeResult.data as Map<String, dynamic>;
      final expenses = expenseResult.data as Map<String, dynamic>;
      final invoices = invoiceResult.data as Map<String, dynamic>;

      final totalIncome = income['total'] as double? ?? 0;
      final totalProfit = income['profit'] as double? ?? 0;
      final totalExpenses = expenses['total'] as double? ?? 0;
      final outstanding = invoices['outstanding'] as double? ?? 0;

      return FinancialToolResult.success({
        'totalIncome': totalIncome,
        'totalProfit': totalProfit,
        'totalExpenses': totalExpenses,
        'netCashFlow': totalIncome - totalExpenses,
        'accountsReceivable': outstanding,
        'profitMargin': totalIncome > 0 ? (totalProfit / totalIncome * 100) : 0,
      });
    } catch (e) {
      debugPrint('[FinancialTools] getFinancialSummary error: $e');
      return FinancialToolResult.failure(
          'Failed to generate financial summary: $e');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
