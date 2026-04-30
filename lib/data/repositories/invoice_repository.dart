import '../models/business_model.dart';
import '../database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/quotation_model.dart';
import '../models/product_model.dart';
import '../services/cloud_sync_service.dart';

class InvoiceRepository {
  Stream<List<InvoiceModel>> watchInvoices(String businessId) {
    return CloudSyncService.instance.watchInvoices(businessId).asyncMap((_) async {
      final data = await DBHelper.getInvoices(businessId);
      return data.map((e) => InvoiceModel.fromMap(e)).toList();
    });
  }

  Stream<InvoiceModel?> watchInvoiceById(String businessId, String id) {
    return CloudSyncService.instance.watchInvoice(id, businessId).asyncMap((_) async {
      final data = await DBHelper.getInvoiceById(businessId, id);
      return data != null ? InvoiceModel.fromMap(data) : null;
    });
  }

  Stream<List<Map<String, dynamic>>> watchInvoiceItems(String businessId, String id) {
    return CloudSyncService.instance.watchInvoiceItems(id, businessId);
  }

  Stream<List<QuotationModel>> watchQuotations(String businessId) {
    return CloudSyncService.instance.watchQuotations(businessId).asyncMap((_) async {
      final data = await DBHelper.getQuotations(businessId);
      return data.map((e) => QuotationModel.fromMap(e)).toList();
    });
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
  }) {
    return DBHelper.createInvoice(
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
  }) {
    return DBHelper.updateInvoicePdfPath(
      businessId: businessId,
      invoiceId: invoiceId,
      pdfPath: pdfPath,
    );
  }

  Future<int> updateQuotationPdfPath({
    required String businessId,
    required String quotationId,
    required String pdfPath,
  }) {
    return DBHelper.updateQuotationPdfPath(
      businessId: businessId,
      quotationId: quotationId,
      pdfPath: pdfPath,
    );
  }

  Future<void> addInvoicePayment({
    required String businessId,
    required String invoiceId,
    required double amount,
    required String paymentMethod,
  }) {
    return DBHelper.addInvoicePayment(
      businessId: businessId,
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: paymentMethod,
    );
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
  }) {
    return DBHelper.createQuotation(
      businessId: businessId,
      customerId: customerId,
      items: items,
      status: status,
      issueDate: issueDate,
      expiryDate: expiryDate,
      notes: notes,
      currencyCode: currencyCode,
    );
  }

  Future<QuotationModel?> getQuotationById(String businessId, String id) async {
    final data = await DBHelper.getQuotationById(businessId, id);
    return data != null ? QuotationModel.fromMap(data) : null;
  }

  Future<List<Map<String, dynamic>>> getQuotationItems(String businessId, String id) {
    return DBHelper.getQuotationItems(businessId, id);
  }

  Future<void> deleteInvoice(String businessId, String id) {
    return DBHelper.deleteInvoice(businessId, id);
  }

  Future<void> deleteQuotation(String businessId, String id) {
    return DBHelper.deleteQuotation(businessId, id);
  }
}
