import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';

class InvoiceRepository {
  Stream<List<Map<String, dynamic>>> watchInvoices() {
    return CloudSyncService.instance
        .watchInvoices()
        .asyncMap((_) => DBHelper.getInvoices());
  }

  Stream<Map<String, dynamic>?> watchInvoiceById(String id) {
    return CloudSyncService.instance
        .watchInvoice(id)
        .asyncMap((_) => DBHelper.getInvoiceById(id));
  }

  Stream<List<Map<String, dynamic>>> watchInvoiceItems(String id) {
    return CloudSyncService.instance.watchInvoiceItems(id);
  }

  Stream<List<Map<String, dynamic>>> watchQuotations() {
    return CloudSyncService.instance
        .watchQuotations()
        .asyncMap((_) => DBHelper.getQuotations());
  }

  Future<List<Map<String, dynamic>>> getInvoices() {
    return DBHelper.getInvoices();
  }

  Future<List<Map<String, dynamic>>> getQuotations() {
    return DBHelper.getQuotations();
  }

  Future<List<Map<String, dynamic>>> getCustomers() {
    return DBHelper.getCustomers();
  }

  Future<List<Map<String, dynamic>>> getProducts() {
    return DBHelper.getProducts();
  }

  Future<Map<String, dynamic>?> getBusinessProfile() {
    return DBHelper.getBusinessProfile();
  }

  Future<String> createInvoice({
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

  Future<Map<String, dynamic>?> getInvoiceById(String id) {
    return DBHelper.getInvoiceById(id);
  }

  Future<List<Map<String, dynamic>>> getInvoiceItems(String id) {
    return DBHelper.getInvoiceItems(id);
  }

  Future<List<Map<String, dynamic>>> getInvoicePayments(String id) {
    return DBHelper.getInvoicePayments(id);
  }

  Future<int> updateInvoicePdfPath({
    required String invoiceId,
    required String pdfPath,
  }) {
    return DBHelper.updateInvoicePdfPath(
      invoiceId: invoiceId,
      pdfPath: pdfPath,
    );
  }

  Future<int> updateQuotationPdfPath({
    required String quotationId,
    required String pdfPath,
  }) {
    return DBHelper.updateQuotationPdfPath(
      quotationId: quotationId,
      pdfPath: pdfPath,
    );
  }

  Future<void> addInvoicePayment({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
  }) {
    return DBHelper.addInvoicePayment(
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: paymentMethod,
    );
  }

  Future<String> createQuotation({
    required String customerId,
    required List<Map<String, dynamic>> items,
    required String status,
    String? issueDate,
    String? expiryDate,
    String? notes,
    String? currencyCode,
  }) {
    return DBHelper.createQuotation(
      customerId: customerId,
      items: items,
      status: status,
      issueDate: issueDate,
      expiryDate: expiryDate,
      notes: notes,
      currencyCode: currencyCode,
    );
  }

  Future<Map<String, dynamic>?> getQuotationById(String id) {
    return DBHelper.getQuotationById(id);
  }

  Future<List<Map<String, dynamic>>> getQuotationItems(String id) {
    return DBHelper.getQuotationItems(id);
  }

  Future<void> deleteInvoice(String id) {
    return DBHelper.deleteInvoice(id);
  }

  Future<void> deleteQuotation(String id) {
    return DBHelper.deleteQuotation(id);
  }
}
