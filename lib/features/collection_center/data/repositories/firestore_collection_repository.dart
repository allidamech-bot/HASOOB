import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/collection_repository.dart';
import '../models/invoice_model.dart';
import '../models/payment_model.dart';

class FirestoreCollectionRepository implements CollectionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _invoicesCollection => _firestore.collection('invoices');
  CollectionReference get _paymentsCollection => _firestore.collection('payments');

  @override
  Stream<List<InvoiceModel>> getInvoices() {
    return _invoicesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return InvoiceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  @override
  Stream<List<PaymentModel>> getPayments() {
    return _paymentsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  @override
  Future<void> addInvoice(InvoiceModel invoice) async {
    await _invoicesCollection.add(invoice.toMap());
  }

  @override
  Future<void> updateInvoice(InvoiceModel invoice) async {
    await _invoicesCollection.doc(invoice.id).update(invoice.toMap());
  }

  @override
  Future<void> addPayment(PaymentModel payment) async {
    await _paymentsCollection.add(payment.toMap());
  }
}
