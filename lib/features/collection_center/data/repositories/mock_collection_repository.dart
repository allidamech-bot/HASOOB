import 'dart:async';
import '../../domain/repositories/collection_repository.dart';
import '../models/invoice_model.dart';
import '../models/payment_model.dart';

class MockCollectionRepository implements CollectionRepository {
  final List<InvoiceModel> _mockInvoices = [
    InvoiceModel(id: 'inv1', customerId: 'c1', customerName: 'مؤسسة أحمد التجارية', items: [{'name': 'حاسوب محمول', 'qty': 2, 'price': 1200.0}], subtotal: 2400.0, total: 2400.0, status: 'paid', createdAt: DateTime.now().subtract(const Duration(days: 5)), dueDate: DateTime.now().add(const Duration(days: 10))),
    InvoiceModel(id: 'inv2', customerId: 'c2', customerName: 'شركة النور للتوريدات', items: [{'name': 'شاشة 4K', 'qty': 4, 'price': 350.0}], subtotal: 1400.0, total: 1400.0, status: 'sent', createdAt: DateTime.now().subtract(const Duration(days: 2)), dueDate: DateTime.now().add(const Duration(days: 5))),
    InvoiceModel(id: 'inv3', customerId: 'c1', customerName: 'مؤسسة أحمد التجارية', items: [{'name': 'ملحقات متنوعة', 'qty': 10, 'price': 50.0}], subtotal: 500.0, total: 500.0, status: 'overdue', createdAt: DateTime.now().subtract(const Duration(days: 20)), dueDate: DateTime.now().subtract(const Duration(days: 5))),
  ];

  final List<PaymentModel> _mockPayments = [
    PaymentModel(id: 'p1', invoiceId: 'inv1', customerId: 'c1', customerName: 'مؤسسة أحمد التجارية', amount: 2400.0, method: 'bank', createdAt: DateTime.now().subtract(const Duration(days: 4))),
  ];

  final _invoiceController = StreamController<List<InvoiceModel>>.broadcast();
  final _paymentController = StreamController<List<PaymentModel>>.broadcast();

  MockCollectionRepository() {
    _invoiceController.add(_mockInvoices);
    _paymentController.add(_mockPayments);
  }

  @override
  Stream<List<InvoiceModel>> getInvoices() {
    Timer(const Duration(milliseconds: 300), () => _invoiceController.add(_mockInvoices));
    return _invoiceController.stream;
  }

  @override
  Stream<List<PaymentModel>> getPayments() {
    Timer(const Duration(milliseconds: 300), () => _paymentController.add(_mockPayments));
    return _paymentController.stream;
  }

  @override
  Future<void> addInvoice(InvoiceModel invoice) async {
    _mockInvoices.add(invoice);
    _invoiceController.add(_mockInvoices);
  }

  @override
  Future<void> updateInvoice(InvoiceModel invoice) async {
    final index = _mockInvoices.indexWhere((element) => element.id == invoice.id);
    if (index != -1) {
      _mockInvoices[index] = invoice;
      _invoiceController.add(_mockInvoices);
    }
  }

  @override
  Future<void> addPayment(PaymentModel payment) async {
    _mockPayments.add(payment);
    _paymentController.add(_mockPayments);
  }
}
