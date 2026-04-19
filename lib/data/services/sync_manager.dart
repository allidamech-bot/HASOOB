import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'cloud_sync_service.dart';

class SyncManager {
  SyncManager._();

  static final SyncManager instance = SyncManager._();

  bool _isProcessing = false;
  bool _isPulling = false;
  bool _isInitialized = false;

  Timer? _pushTimer;
  Timer? _pullTimer;
  Timer? _debounceTimer;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _productsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _customersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _invoicesSubscription;

  final Connectivity _connectivity = Connectivity();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _pushTimer?.cancel();
    _pullTimer?.cancel();

    _pushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(processQueue()),
    );

    _pullTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => unawaited(pullSync()),
    );

    await stopRealtimeSync();
    startRealtimeSync();

    unawaited(processQueue());
    unawaited(pullSync());
  }

  Future<void> onAuthenticated() async {
    await initialize();
    await stopRealtimeSync();
    if (await DBHelper.isLocalBusinessDataEmpty()) {
      await replaceLocalCacheWithCloud();
    } else {
      await _processQueueNow();
      await pullSync();
    }
    startRealtimeSync();

    unawaited(processQueue());
    unawaited(pullSync());
  }

  Future<void> onAppResumed() async {
    await initialize();

    await stopRealtimeSync();
    startRealtimeSync();

    unawaited(processQueue());
    unawaited(pullSync());
  }

  void startRealtimeSync() {
    if (_productsSubscription != null ||
        _customersSubscription != null ||
        _invoicesSubscription != null) {
      return;
    }

    debugPrint('Realtime sync started');

    _productsSubscription = CloudSyncService.instance.listenToProducts(
      (change) => unawaited(_handleProductRealtimeChange(change)),
    );

    _customersSubscription = CloudSyncService.instance.listenToCustomers(
      (change) => unawaited(_handleCustomerRealtimeChange(change)),
    );

    _invoicesSubscription = CloudSyncService.instance.listenToInvoices(
      (change) => unawaited(_handleInvoiceRealtimeChange(change)),
    );
  }

  Future<void> stopRealtimeSync() async {
    await _productsSubscription?.cancel();
    await _customersSubscription?.cancel();
    await _invoicesSubscription?.cancel();
    _productsSubscription = null;
    _customersSubscription = null;
    _invoicesSubscription = null;

    debugPrint('Realtime sync stopped');
  }

  Future<void> processQueue() async {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _debounceTimer = null;
      unawaited(_processQueueNow());
    });
  }

  Future<void> _processQueueNow() async {
    if (_isProcessing) {
      debugPrint('Sync skipped: already processing');
      return;
    }

    if (!await _isOnline()) {
      debugPrint('Skipped: offline');
      return;
    }

    _isProcessing = true;

    try {
      debugPrint('Push sync started');

      final db = await DBHelper.database();
      final queueItems = await db.query(
        'sync_queue',
        orderBy: 'created_at ASC',
      );

      if (queueItems.isEmpty) {
        debugPrint('Sync queue is empty');
        return;
      }

      final batch = queueItems.take(20).toList();

      for (final item in batch) {
        final queueId = item['id']?.toString() ?? '';
        if (queueId.isEmpty) continue;

        final retryCount = item['retry_count'] is num
            ? (item['retry_count'] as num).toInt()
            : int.tryParse(item['retry_count']?.toString() ?? '0') ?? 0;

        if (retryCount >= 5) continue;

        try {
          final entityType = item['entity_type']?.toString() ?? '';
          final entityId = item['entity_id']?.toString() ?? '';
          final action = item['action']?.toString() ?? '';
          final payload = _decodePayload(item['payload']?.toString() ?? '{}');

          await _processQueueItem(
            entityType: entityType,
            entityId: entityId,
            action: action,
            payload: payload,
          );

          await db.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [queueId],
          );
        } catch (_) {
          await db.rawUpdate(
            'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
            [queueId],
          );
        }
      }

      debugPrint('Push sync success');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> pullSync() async {
    if (_isPulling) return;
    if (!await _isOnline()) return;

    _isPulling = true;

    try {
      debugPrint('Pull sync started');

      final products = await CloudSyncService.instance.fetchProducts();
      final customers = await CloudSyncService.instance.fetchCustomers();
      final invoices = await CloudSyncService.instance.fetchInvoices();
      final db = await DBHelper.database();

      await db.transaction((txn) async {
        for (final product in products) {
          final productId = (product['id'] ?? '').toString();
          if (productId.isEmpty) continue;

          await txn.insert(
            'products',
            {
              'id': productId,
              'name': product['name']?.toString() ?? '',
              'unit': product['unit']?.toString() ?? '',
              'purchase_price': _toDouble(product['purchase_price']),
              'extra_costs': _toDouble(product['extra_costs']),
              'selling_price': _toDouble(product['selling_price']),
              'stock_qty': _toInt(product['stock_qty']),
              'low_stock_threshold': _toInt(product['low_stock_threshold']),
              'barcode': product['barcode']?.toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final customer in customers) {
          final payload = _sanitizeCustomerForLocal(customer);
          if ((payload['id'] ?? '').toString().isEmpty) continue;

          await txn.insert(
            'customers',
            payload,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final invoice in invoices) {
          final payload = _sanitizeInvoiceForLocal(invoice);
          if ((payload['id'] ?? '').toString().isEmpty) continue;

          await txn.insert(
            'invoices',
            payload,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      debugPrint('Pull sync success');
    } finally {
      _isPulling = false;
    }
  }

  Future<void> replaceLocalCacheWithCloud() async {
    if (!await _isOnline()) return;

    final service = CloudSyncService.instance;
    final businessProfile = await service.fetchBusinessProfile();
    final products = await service.fetchProducts();
    final customers = await service.fetchCustomers();
    final quotations = await service.fetchQuotations();
    final quotationItems = await service.fetchQuotationItems();
    final invoices = await service.fetchInvoices();
    final invoiceItems = await service.fetchInvoiceItems();
    final payments = await service.fetchPayments();
    final accounts = await service.fetchAccounts();
    final salesRecords = await service.fetchSalesRecords();
    final journalEntries = await service.fetchJournalEntries();
    final productMovements = await service.fetchProductMovements();

    await DBHelper.replaceLocalBusinessCache(
      businessProfile: businessProfile,
      products: products,
      customers: customers,
      quotations: quotations,
      quotationItems: quotationItems,
      invoices: invoices,
      invoiceItems: invoiceItems,
      payments: payments,
      accounts: accounts,
      salesRecords: salesRecords,
      journalEntries: journalEntries,
      productMovements: productMovements,
    );
  }

  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();

    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }

    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    return true;
  }

  Map<String, dynamic> _decodePayload(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _handleProductRealtimeChange(
    DocumentChange<Map<String, dynamic>> change,
  ) async {
    final db = await DBHelper.database();
    final data = change.doc.data() ?? {};
    final id = (data['id'] ?? change.doc.id).toString();

    if (id.isEmpty) return;

    if (change.type == DocumentChangeType.removed) {
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
      return;
    }

    await db.insert(
      'products',
      {
        'id': id,
        'name': data['name']?.toString() ?? '',
        'unit': data['unit']?.toString() ?? '',
        'purchase_price': _toDouble(data['purchase_price']),
        'extra_costs': _toDouble(data['extra_costs']),
        'selling_price': _toDouble(data['selling_price']),
        'stock_qty': _toInt(data['stock_qty']),
        'low_stock_threshold': _toInt(data['low_stock_threshold']),
        'barcode': data['barcode']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _handleCustomerRealtimeChange(
    DocumentChange<Map<String, dynamic>> change,
  ) async {
    final db = await DBHelper.database();
    final data = change.doc.data() ?? {};
    final id = (data['id'] ?? change.doc.id).toString();

    if (id.isEmpty) return;

    if (change.type == DocumentChangeType.removed) {
      await db.delete('customers', where: 'id = ?', whereArgs: [id]);
      return;
    }

    await db.insert(
      'customers',
      _sanitizeCustomerForLocal({'id': id, ...data}),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _handleInvoiceRealtimeChange(
    DocumentChange<Map<String, dynamic>> change,
  ) async {
    final db = await DBHelper.database();
    final data = change.doc.data() ?? {};
    final id = (data['id'] ?? change.doc.id).toString();

    if (id.isEmpty) return;

    if (change.type == DocumentChangeType.removed) {
      await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
      return;
    }

    await db.insert(
      'invoices',
      _sanitizeInvoiceForLocal({'id': id, ...data}),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _processQueueItem({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final service = CloudSyncService.instance;

    if (entityType == 'products') {
      if (action == 'delete') return service.deleteProduct(entityId);
      return service.upsertProduct(payload);
    }

    if (entityType == 'customers') {
      if (action == 'delete') return service.deleteCustomer(entityId);
      return service.upsertCustomer(payload);
    }

    if (entityType == 'invoices') {
      if (action == 'delete') return service.deleteInvoice(entityId);
      await service.upsertInvoice(payload);

      final items = (payload['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      if (items.isNotEmpty) {
        await service.upsertInvoiceItems(entityId, items);
      }

      final payments = (payload['payments'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      for (final payment in payments) {
        await service.upsertPayment(payment);
      }

      final quotation = payload['quotation'];
      if (quotation is Map) {
        final quotationMap = quotation.map((k, v) => MapEntry(k.toString(), v));
        final quotationItems =
            (payload['quotation_items'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
                .toList();
        await service.upsertQuotation(quotationMap, items: quotationItems);
      }
      return;
    }

    if (entityType == 'business_profile') {
      return service.upsertBusinessProfile(payload);
    }

    if (entityType == 'quotations') {
      final items = (payload['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      return service.upsertQuotation(payload, items: items);
    }

    if (entityType == 'payments') {
      return service.upsertPayment(payload);
    }

    if (entityType == 'product_movements') {
      return service.upsertProductMovement(payload);
    }

    if (entityType == 'sales_records') {
      return service.addSaleRecord(payload);
    }

    if (entityType == 'journal_entries') {
      return service.addJournalEntry(payload);
    }

    if (entityType == 'accounts') {
      return service.syncAccounts([payload]);
    }
  }

  Map<String, dynamic> _sanitizeCustomerForLocal(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString() ?? '',
      'name': data['name']?.toString() ?? '',
      'phone': data['phone']?.toString(),
      'notes': data['notes']?.toString(),
      'branch_id': data['branch_id']?.toString(),
      'created_by': data['created_by']?.toString(),
      'created_at': data['created_at']?.toString(),
    };
  }

  Map<String, dynamic> _sanitizeInvoiceForLocal(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString() ?? '',
      'invoice_number': data['invoice_number']?.toString(),
      'customer_id': data['customer_id']?.toString(),
      'quotation_id': data['quotation_id']?.toString(),
      'status': data['status']?.toString(),
      'issue_date': data['issue_date']?.toString(),
      'due_date': data['due_date']?.toString(),
      'subtotal': _toDouble(data['subtotal']),
      'total': _toDouble(data['total']),
      'paid_amount': _toDouble(data['paid_amount']),
      'remaining_amount': _toDouble(data['remaining_amount']),
      'notes': data['notes']?.toString(),
      'currency_code': data['currency_code']?.toString(),
      'created_by': data['created_by']?.toString(),
      'branch_id': data['branch_id']?.toString(),
      'payment_method': data['payment_method']?.toString(),
      'accounting_posted': _toInt(data['accounting_posted']),
      'pdf_path': data['pdf_path']?.toString(),
      'discount': _toDouble(data['discount']),
      'tax': _toDouble(data['tax']),
    };
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
