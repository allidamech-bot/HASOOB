import '../../data/models/invoice_model.dart';
import '../../data/models/payment_model.dart';

abstract class CollectionRepository {
  Stream<List<InvoiceModel>> getInvoices();
  Stream<List<PaymentModel>> getPayments();
  Future<void> addInvoice(InvoiceModel invoice);
  Future<void> updateInvoice(InvoiceModel invoice);
  Future<void> addPayment(PaymentModel payment);
}
