import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sync_service.dart';

class CloudSyncService implements SyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get _uid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _productsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('products');

  CollectionReference<Map<String, dynamic>> _salesRecordsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('sales_records');

  CollectionReference<Map<String, dynamic>> _journalEntriesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('journal_entries');

  CollectionReference<Map<String, dynamic>> _accountsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('accounts');

  CollectionReference<Map<String, dynamic>> _invoicesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('invoices');

  CollectionReference<Map<String, dynamic>> _customersRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('customers');

  DocumentReference<Map<String, dynamic>> _businessProfileRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('meta').doc('business_profile');

  CollectionReference<Map<String, dynamic>> _quotationsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('quotations');

  CollectionReference<Map<String, dynamic>> _quotationItemsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('quotation_items');

  CollectionReference<Map<String, dynamic>> _invoiceItemsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('invoice_items');

  CollectionReference<Map<String, dynamic>> _paymentsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('payments');

  CollectionReference<Map<String, dynamic>> _productMovementsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('product_movements');

  Map<String, dynamic> _ownedPayload(
    String uid,
    Map<String, dynamic> data, {
    String? id,
    bool touchUpdatedAt = true,
  }) {
    final payload = Map<String, dynamic>.from(data);
    if (id != null && id.isNotEmpty) {
      payload['id'] = id;
    }
    payload['owner_id'] = uid;
    payload['ownerId'] = uid;
    payload['user_id'] = uid;
    if (touchUpdatedAt) {
      payload['updated_at'] ??= DateTime.now().toIso8601String();
    }
    return payload;
  }

  @override
  Future<void> upsertProduct(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('CloudSyncService.upsertProduct skipped: no user');
      return;
    }

    final productId = data['id']?.toString();
    if (productId == null || productId.isEmpty) {
      debugPrint('CloudSyncService.upsertProduct skipped: missing product id');
      return;
    }

    await _productsRef(uid).doc(productId).set(
      _ownedPayload(uid, data, id: productId),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteProduct(String id) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;
    await _productsRef(uid).doc(id).delete();
  }

  @override
  Future<void> upsertCustomer(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('CloudSyncService.upsertCustomer skipped: no user');
      return;
    }

    final customerId = data['id']?.toString();
    if (customerId == null || customerId.isEmpty) {
      debugPrint('CloudSyncService.upsertCustomer skipped: missing customer id');
      return;
    }

    final payload = _ownedPayload(uid, data, id: customerId);

    await _customersRef(uid).doc(customerId).set(
      payload,
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;
    await _customersRef(uid).doc(id).delete();
  }

  Future<void> upsertInvoice(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('CloudSyncService.upsertInvoice skipped: no user');
      return;
    }

    final invoiceId = data['id']?.toString();
    if (invoiceId == null || invoiceId.isEmpty) {
      debugPrint('CloudSyncService.upsertInvoice skipped: missing invoice id');
      return;
    }

    await _invoicesRef(uid).doc(invoiceId).set(
      _ownedPayload(uid, data, id: invoiceId),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteInvoice(String id) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;

    await _invoicesRef(uid).doc(id).delete();
  }

  Future<void> upsertBusinessProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('CloudSyncService.upsertBusinessProfile skipped: no user');
      return;
    }

    final payload = _ownedPayload(uid, data)
      ..['id'] = 1
      ..['updated_at'] = DateTime.now().toIso8601String();

    await _businessProfileRef(uid).set(payload, SetOptions(merge: true));
  }

  Future<void> upsertQuotation(
    Map<String, dynamic> data, {
    List<Map<String, dynamic>> items = const [],
  }) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('CloudSyncService.upsertQuotation skipped: no user');
      return;
    }

    final quotationId = data['id']?.toString();
    if (quotationId == null || quotationId.isEmpty) {
      debugPrint('CloudSyncService.upsertQuotation skipped: missing quotation id');
      return;
    }

    final payload = _ownedPayload(uid, data, id: quotationId)
      ..['updated_at'] = DateTime.now().toIso8601String();

    await _quotationsRef(uid).doc(quotationId).set(
      payload,
      SetOptions(merge: true),
    );

    if (items.isNotEmpty) {
      final batch = _firestore.batch();
      final existingItems = await _quotationItemsRef(uid)
          .where('quotation_id', isEqualTo: quotationId)
          .get();
      for (final doc in existingItems.docs) {
        batch.delete(doc.reference);
      }
      for (var index = 0; index < items.length; index++) {
        final item = Map<String, dynamic>.from(items[index]);
        final itemId = item['id']?.toString().trim().isNotEmpty == true
            ? item['id'].toString()
            : '${quotationId}_$index';
        batch.set(
          _quotationItemsRef(uid).doc(itemId),
          _ownedPayload(
            uid,
            {
              ...item,
              'quotation_id': quotationId,
              'sort_order': index,
            },
            id: itemId,
          ),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> upsertInvoiceItems(
    String invoiceId,
    List<Map<String, dynamic>> items,
  ) async {
    final uid = _uid;
    if (uid == null || invoiceId.isEmpty) return;

    final batch = _firestore.batch();
    final existingItems = await _invoiceItemsRef(uid)
        .where('invoice_id', isEqualTo: invoiceId)
        .get();
    for (final doc in existingItems.docs) {
      batch.delete(doc.reference);
    }
    for (var index = 0; index < items.length; index++) {
      final item = Map<String, dynamic>.from(items[index]);
      final itemId = item['id']?.toString().trim().isNotEmpty == true
          ? item['id'].toString()
          : '${invoiceId}_$index';
      batch.set(
        _invoiceItemsRef(uid).doc(itemId),
        _ownedPayload(
          uid,
          {
            ...item,
            'invoice_id': invoiceId,
            'sort_order': index,
          },
          id: itemId,
        ),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> upsertPayment(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;
    final paymentId = data['id']?.toString();
    if (paymentId == null || paymentId.isEmpty) return;
    await _paymentsRef(uid).doc(paymentId).set(
      _ownedPayload(uid, data, id: paymentId)
        ..['updated_at'] = DateTime.now().toIso8601String(),
      SetOptions(merge: true),
    );
  }

  Future<void> upsertProductMovement(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;
    final movementId = data['id']?.toString();
    if (movementId == null || movementId.isEmpty) return;
    await _productMovementsRef(uid).doc(movementId).set(
      _ownedPayload(uid, data, id: movementId)
        ..['updated_at'] = DateTime.now().toIso8601String(),
      SetOptions(merge: true),
    );
  }

  Future<void> addSaleRecord(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;

    final payload = _ownedPayload(uid, data, touchUpdatedAt: false);
    final saleId = payload['id']?.toString();

    if (saleId != null && saleId.isNotEmpty) {
      await _salesRecordsRef(uid).doc(saleId).set(
        payload,
        SetOptions(merge: true),
      );
      return;
    }

    await _salesRecordsRef(uid).add(payload);
  }

  Future<void> addJournalEntry(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;

    final payload = _ownedPayload(uid, data, touchUpdatedAt: false);
    final journalId = payload['id']?.toString();

    if (journalId != null && journalId.isNotEmpty) {
      await _journalEntriesRef(uid).doc(journalId).set(
        payload,
        SetOptions(merge: true),
      );
      return;
    }

    await _journalEntriesRef(uid).add(payload);
  }

  Future<void> syncAccounts(List<Map<String, dynamic>> accounts) async {
    final uid = _uid;
    if (uid == null || accounts.isEmpty) return;

    final batch = _firestore.batch();

    for (final account in accounts) {
      final accountId = account['id']?.toString();
      if (accountId == null || accountId.isEmpty) continue;

      batch.set(
        _accountsRef(uid).doc(accountId),
        _ownedPayload(uid, account, id: accountId, touchUpdatedAt: false),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> fetchProducts(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _productsRef(uid).where('businessId', isEqualTo: businessId).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCustomers(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _customersRef(uid).where('businessId', isEqualTo: businessId).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchInvoices(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _invoicesRef(uid).where('businessId', isEqualTo: businessId).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> fetchBusinessProfile(String businessId) async {
    final uid = _uid;
    if (uid == null) return null;

    final snapshot = await _businessProfileRef(uid).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data() ?? {};
    if (data['businessId'] != businessId) return null;
    return {
      'id': 1,
      ...data,
    };
  }

  Future<List<Map<String, dynamic>>> fetchQuotations(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _quotationsRef(uid).where('businessId', isEqualTo: businessId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchQuotationItems(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _quotationItemsRef(uid)
        .where('businessId', isEqualTo: businessId)
        .orderBy('sort_order')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchInvoiceItems(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _invoiceItemsRef(uid)
        .where('businessId', isEqualTo: businessId)
        .orderBy('sort_order')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPayments(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _paymentsRef(uid).where('businessId', isEqualTo: businessId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchProductMovements(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _productMovementsRef(uid).where('businessId', isEqualTo: businessId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchProducts(String businessId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _productsRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs.map(_mapDoc).toList();
      rows.sort((a, b) => _compareText(a['name'], b['name']));
      return rows;
    });
  }

  Stream<List<Map<String, dynamic>>> watchCustomers(String businessId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _customersRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs.map(_mapDoc).toList();
      rows.sort((a, b) => _compareText(a['name'], b['name']));
      return rows;
    });
  }

  Stream<List<Map<String, dynamic>>> watchInvoices(String businessId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _invoicesRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs.map(_mapDoc).toList();
      rows.sort(_compareDocumentsByDateAndNumber);
      return rows;
    });
  }

  Stream<Map<String, dynamic>?> watchInvoice(String invoiceId, String businessId) {
    final uid = _uid;
    if (uid == null || invoiceId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _invoicesRef(uid).doc(invoiceId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = _mapDoc(snapshot);
      if (data['businessId'] != businessId) return null;
      return data;
    });
  }

  Stream<List<Map<String, dynamic>>> watchInvoiceItems(String invoiceId, String businessId) {
    final uid = _uid;
    if (uid == null || invoiceId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _invoiceItemsRef(uid)
        .where('invoice_id', isEqualTo: invoiceId)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs.map(_mapDoc).toList();
      rows.sort((a, b) {
        final aOrder = _toInt(a['sort_order']);
        final bOrder = _toInt(b['sort_order']);
        return aOrder.compareTo(bOrder);
      });
      return rows;
    });
  }

  Stream<List<Map<String, dynamic>>> watchQuotations(String businessId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _quotationsRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs.map(_mapDoc).toList();
      rows.sort(_compareDocumentsByDateAndNumber);
      return rows;
    });
  }

  Stream<List<Map<String, dynamic>>> watchSalesRecords(String businessId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _salesRecordsRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs.map(_mapDoc).toList();
      rows.sort((a, b) => _compareDateDesc(a['date'], b['date']));
      return rows;
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listenToCustomers(
    String businessId,
    void Function(DocumentChange<Map<String, dynamic>> change) onChange,
  ) {
    final uid = _uid;
    if (uid == null) return null;

    return _customersRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        onChange(change);
      }
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listenToProducts(
    String businessId,
    void Function(DocumentChange<Map<String, dynamic>> change) onChange,
  ) {
    final uid = _uid;
    if (uid == null) return null;

    return _productsRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        onChange(change);
      }
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listenToInvoices(
    String businessId,
    void Function(DocumentChange<Map<String, dynamic>> change) onChange,
  ) {
    final uid = _uid;
    if (uid == null) return null;

    return _invoicesRef(uid)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        onChange(change);
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchAccounts(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _accountsRef(uid).where('businessId', isEqualTo: businessId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? int.tryParse(doc.id) ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchSalesRecords(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _salesRecordsRef(uid).where('businessId', isEqualTo: businessId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? int.tryParse(doc.id) ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchJournalEntries(String businessId) async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _journalEntriesRef(uid).where('businessId', isEqualTo: businessId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? int.tryParse(doc.id) ?? doc.id,
        ...data,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> getLocalRestoreStatus() async {
    final file = await _restoreStatusFile();
    if (!await file.exists()) {
      return {
        'has_restored': false,
        'last_restore_at': null,
      };
    }

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return {
        'has_restored': json['has_restored'] == true,
        'last_restore_at': json['last_restore_at']?.toString(),
      };
    } catch (_) {
      return {
        'has_restored': false,
        'last_restore_at': null,
      };
    }
  }

  Future<void> markLocalRestoreUsed() async {
    final file = await _restoreStatusFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'has_restored': true,
        'last_restore_at': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  Future<File> _restoreStatusFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'Hasoob', 'restore_status.json'));
  }

  Map<String, dynamic> _mapDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return {
      'id': data['id'] ?? doc.id,
      ...data,
    };
  }

  int _compareDocumentsByDateAndNumber(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final dateComparison = _compareDateDesc(
      a['issue_date'] ?? a['date'] ?? a['created_at'],
      b['issue_date'] ?? b['date'] ?? b['created_at'],
    );
    if (dateComparison != 0) return dateComparison;

    return _compareTextDesc(
      a['invoice_number'] ?? a['quotation_number'] ?? a['id'],
      b['invoice_number'] ?? b['quotation_number'] ?? b['id'],
    );
  }

  int _compareDateDesc(dynamic a, dynamic b) {
    final aDate = _parseDate(a);
    final bDate = _parseDate(b);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  int _compareText(dynamic a, dynamic b) {
    return (a?.toString() ?? '').toLowerCase().compareTo(
          (b?.toString() ?? '').toLowerCase(),
        );
  }

  int _compareTextDesc(dynamic a, dynamic b) {
    return _compareText(b, a);
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
