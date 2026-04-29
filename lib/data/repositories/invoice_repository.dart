import '../models/business_model.dart';
import '../database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/quotation_model.dart';
import '../models/product_model.dart';
import '../services/cloud_sync_service.dart';

class InvoiceRepository {
  Stream<List<InvoiceModel>> watchInvoices() {
    return CloudSyncService.instance.watchInvoices().asyncMap((_) async {
      final data = await DBHelper.getInvoices();
      return data.map((e) => InvoiceModel.fromMap(e)).toList();
    });
  }

  Stream<InvoiceModel?> watchInvoiceById(String id) {
    return CloudSyncService.instance.watchInvoice(id).asyncMap((_) async {
      final data = await DBHelper.getInvoiceById(id);
      return data != null ? InvoiceModel.fromMap(data) : null;
    });
  }

  Stream<List<Map<String, dynamic>>> watchInvoiceItems(String id) {
    return CloudSyncService.instance.watchInvoiceItems(id);
  }

  Stream<List<QuotationModel>> watchQuotations() {
    return CloudSyncService.instance.watchQuotations().asyncMap((_) async {
      final data = await DBHelper.getQuotations();
      return data.map((e) => QuotationModel.fromMap(e)).toList();
    });
  }

  Future<List<InvoiceModel>> getInvoices() async {
    final data = await DBHelper.getInvoices();
    return data.map((e) => InvoiceModel.fromMap(e)).toList();
  }

  Future<List<QuotationModel>> getQuotations() async {
    final data = await DBHelper.getQuotations();
    return data.map((e) => QuotationModel.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomers() {
    return DBHelper.getCustomers();
  }

  Future<List<ProductModel>> getProducts() async {
    final data = await DBHelper.getProducts();
    return data.map((e) => ProductModel.fromMap(e)).toList();
  }

  Future<BusinessModel?> getBusinessProfile() async {
    final data = await DBHelper.getBusinessProfile();
    return data != null ? BusinessModel.fromMap(data) : null;
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

  Future<InvoiceModel?> getInvoiceById(String id) async {
    final data = await DBHelper.getInvoiceById(id);
    return data != null ? InvoiceModel.fromMap(data) : null;
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

  Future<QuotationModel?> getQuotationById(String id) async {
    final data = await DBHelper.getQuotationById(id);
    return data != null ? QuotationModel.fromMap(data) : null;
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
