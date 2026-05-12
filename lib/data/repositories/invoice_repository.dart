import 'package:flutter/foundation.dart';
import '../models/business_model.dart';
import '../database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/quotation_model.dart';
import '../models/product_model.dart';
import '../services/cloud_sync_service.dart';
import '../services/sync_queue_service.dart';
import '../models/sync_operation.dart';

class InvoiceRepository {
  Stream<List<InvoiceModel>> watchInvoices(String businessId) async* {
    // 1. Yield local data immediately
    final localData = await getInvoices(businessId);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    try {
      await for (final _ in CloudSyncService.instance.watchInvoices(businessId)) {
        final refreshedData = await getInvoices(businessId);
        yield refreshedData;
      }
    } catch (e) {
      debugPrint('[InvoiceRepository] watchInvoices cloud stream error: $e');
    }
  }

  Stream<InvoiceModel?> watchInvoiceById(String businessId, String id) async* {
    // 1. Yield local data immediately
    final localData = await getInvoiceById(businessId, id);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    try {
      await for (final _ in CloudSyncService.instance.watchInvoice(id, businessId)) {
        final refreshedData = await getInvoiceById(businessId, id);
        yield refreshedData;
      }
    } catch (e) {
      debugPrint('[InvoiceRepository] watchInvoiceById cloud stream error: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchInvoiceItems(String businessId, String id) async* {
    // 1. Yield local data immediately
    final localData = await getInvoiceItems(businessId, id);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    try {
      await for (final _ in CloudSyncService.instance.watchInvoiceItems(id, businessId)) {
        final refreshedData = await getInvoiceItems(businessId, id);
        yield refreshedData;
      }
    } catch (e) {
      debugPrint('[InvoiceRepository] watchInvoiceItems cloud stream error: $e');
    }
  }

  Stream<List<QuotationModel>> watchQuotations(String businessId) async* {
    // 1. Yield local data immediately
    final localData = await getQuotations(businessId);
    yield localData;

    // 2. Listen to cloud changes and refresh from local DB
    try {
      await for (final _ in CloudSyncService.instance.watchQuotations(businessId)) {
        final refreshedData = await getQuotations(businessId);
        yield refreshedData;
      }
    } catch (e) {
      debugPrint('[InvoiceRepository] watchQuotations cloud stream error: $e');
    }
  }

  Future<List<InvoiceModel>> getInvoices(String businessId) async {
    final data = await DBHelper.getInvoices(businessId);
    return data.map((e) => InvoiceModel.fromMap(e)).toList();
  }

  Future<List<QuotationModel>> getQuotations(String businessId) async {
    final data = await DBHelper.getQuotations(businessId);
    return data.map((e) => QuotationModel.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomers(String businessId) {
    return DBHelper.getCustomers(businessId);
  }

  Future<List<ProductModel>> getProducts(String businessId) async {
    final data = await DBHelper.getProducts(businessId);
    return data.map((e) => ProductModel.fromMap(e)).toList();
  }

  Future<BusinessModel?> getBusinessProfile(String businessId) async {
    final data = await DBHelper.getBusinessProfile(businessId);
    return data != null ? BusinessModel.fromMap(data) : null;
  }

  Future<String> createInvoice({
    required String businessId,
    required String customerId,
    String? quotationId,
    required List<Map<String, dynamic>> items,
    required String status,
    String? issueDate,
    String? dueDate,
    String? notes,
    required double paidAmount,
    required String paymentMethod,
    String? currencyCode,
  }) async {
    final invoiceId = await DBHelper.createInvoice(
      businessId: businessId,
      customerId: customerId,
      quotationId: quotationId,
      items: items,
      status: status,
      issueDate: issueDate,
      dueDate: dueDate,
      notes: notes,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      currencyCode: currencyCode,
    );

    final invoiceData = await DBHelper.getInvoiceById(businessId, invoiceId);
    if (invoiceData != null) {
      await SyncQueueService.instance.enqueue(
        entityName: 'invoices',
        entityId: invoiceId,
        type: SyncOperationType.create,
        payload: invoiceData,
      );

      final invoiceItems = await DBHelper.getInvoiceItems(businessId, invoiceId);
      await SyncQueueService.instance.enqueue(
        entityName: 'invoice_items',
        entityId: invoiceId,
        type: SyncOperationType.create,
        payload: {
          'invoice_id': invoiceId,
          'businessId': businessId,
          'items': invoiceItems,
        },
      );
    }

    return invoiceId;
  }

  Future<InvoiceModel?> getInvoiceById(String businessId, String id) async {
    final data = await DBHelper.getInvoiceById(businessId, id);
    return data != null ? InvoiceModel.fromMap(data) : null;
  }

  Future<List<Map<String, dynamic>>> getInvoiceItems(String businessId, String id) {
    return DBHelper.getInvoiceItems(businessId, id);
  }

  Future<List<Map<String, dynamic>>> getInvoicePayments(String businessId, String id) {
    return DBHelper.getInvoicePayments(businessId, id);
  }

  Future<int> updateInvoicePdfPath({
    required String businessId,
    required String invoiceId,
    required String pdfPath,
  }) async {
    final result = await DBHelper.updateInvoicePdfPath(
      businessId: businessId,
      invoiceId: invoiceId,
      pdfPath: pdfPath,
    );

    final invoiceData = await DBHelper.getInvoiceById(businessId, invoiceId);
    if (invoiceData != null) {
      await SyncQueueService.instance.enqueue(
        entityName: 'invoices',
        entityId: invoiceId,
        type: SyncOperationType.update,
        payload: invoiceData,
      );
    }

    return result;
  }

  Future<int> updateQuotationPdfPath({
    required String businessId,
    required String quotationId,
    required String pdfPath,
  }) async {
    final result = await DBHelper.updateQuotationPdfPath(
      businessId: businessId,
      quotationId: quotationId,
      pdfPath: pdfPath,
    );

    final quotationData = await DBHelper.getQuotationById(businessId, quotationId);
    if (quotationData != null) {
      await SyncQueueService.instance.enqueue(
        entityName: 'quotations',
        entityId: quotationId,
        type: SyncOperationType.update,
        payload: quotationData,
      );
    }

    return result;
  }

  Future<void> addInvoicePayment({
    required String businessId,
    required String invoiceId,
    required double amount,
    required String paymentMethod,
  }) async {
    final paymentId = await DBHelper.addInvoicePayment(
      businessId: businessId,
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: paymentMethod,
    );

    final payments = await DBHelper.getInvoicePayments(businessId, invoiceId);
    final paymentData = payments.firstWhere((p) => p['id'] == paymentId);

    await SyncQueueService.instance.enqueue(
      entityName: 'payments',
      entityId: paymentId,
      type: SyncOperationType.create,
      payload: paymentData,
    );

    final invoiceData = await DBHelper.getInvoiceById(businessId, invoiceId);
    if (invoiceData != null) {
      await SyncQueueService.instance.enqueue(
        entityName: 'invoices',
        entityId: invoiceId,
        type: SyncOperationType.update,
        payload: invoiceData,
      );
    }
  }

  Future<String> createQuotation({
    required String businessId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    required String status,
    String? issueDate,
    String? expiryDate,
    String? notes,
    String? currencyCode,
  }) async {
    final quotationId = await DBHelper.createQuotation(
      businessId: businessId,
      customerId: customerId,
      items: items,
      status: status,
      issueDate: issueDate,
      expiryDate: expiryDate,
      notes: notes,
      currencyCode: currencyCode,
    );

    final quotationData = await DBHelper.getQuotationById(businessId, quotationId);
    if (quotationData != null) {
      final quotationItems = await DBHelper.getQuotationItems(businessId, quotationId);
      await SyncQueueService.instance.enqueue(
        entityName: 'quotations',
        entityId: quotationId,
        type: SyncOperationType.create,
        payload: {
          ...quotationData,
          'items': quotationItems,
        },
      );
    }

    return quotationId;
  }

  Future<QuotationModel?> getQuotationById(String businessId, String id) async {
    final data = await DBHelper.getQuotationById(businessId, id);
    return data != null ? QuotationModel.fromMap(data) : null;
  }

  Future<List<Map<String, dynamic>>> getQuotationItems(String businessId, String id) {
    return DBHelper.getQuotationItems(businessId, id);
  }

  Future<void> deleteInvoice(String businessId, String id) async {
    await DBHelper.deleteInvoice(businessId, id);

    await SyncQueueService.instance.enqueue(
      entityName: 'invoices',
      entityId: id,
      type: SyncOperationType.delete,
      payload: {'id': id, 'businessId': businessId},
    );
  }

  Future<void> deleteQuotation(String businessId, String id) async {
    await DBHelper.deleteQuotation(businessId, id);

    await SyncQueueService.instance.enqueue(
      entityName: 'quotations',
      entityId: id,
      type: SyncOperationType.delete,
      payload: {'id': id, 'businessId': businessId},
    );
  }
}
