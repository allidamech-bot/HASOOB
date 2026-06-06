import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart' show StreamGroup;
import '../../domain/repositories/dashboard_repository.dart';
import '../models/dashboard_summary_model.dart';

class FirestoreDashboardRepository implements DashboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<DashboardSummaryModel> getDashboardSummary() {
    final customersStream = _firestore.collection('customers').snapshots();
    final inventoryStream = _firestore.collection('inventory').snapshots();
    final invoicesStream = _firestore.collection('invoices').snapshots();
    final paymentsStream = _firestore.collection('payments').snapshots();

    return StreamGroup.merge([
      customersStream,
      inventoryStream,
      invoicesStream,
      paymentsStream
    ]).asyncMap((_) async {
      final customersSnap = await _firestore.collection('customers').get();
      final inventorySnap = await _firestore.collection('inventory').get();
      final invoicesSnap = await _firestore.collection('invoices').get();
      final paymentsSnap = await _firestore.collection('payments').get();

      int lowStockCount = inventorySnap.docs.where((doc) {
        final qty = doc.data()['quantity'] ?? 0;
        return qty <= 10;
      }).length;

      return DashboardSummaryModel.fromAggregatedData(
        customerCount: customersSnap.docs.length,
        lowStockCount: lowStockCount,
        invoiceDocs: invoicesSnap.docs.map((d) => d.data()).toList(),
        paymentDocs: paymentsSnap.docs.map((d) => d.data()).toList(),
      );
    });
  }
}
