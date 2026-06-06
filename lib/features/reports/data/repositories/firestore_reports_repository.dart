import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart' show StreamGroup;
import '../../domain/repositories/reports_repository.dart';
import '../models/report_summary_model.dart';

class FirestoreReportsRepository implements ReportsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<ReportSummaryModel> getFinancialSummary() {
    // Aggregates both collections reactively using stream zip combinations
    final invoicesStream = _firestore.collection('invoices').snapshots();
    final paymentsStream = _firestore.collection('payments').snapshots();

    return StreamGroup.merge([invoicesStream, paymentsStream]).asyncMap((_) async {
      final invoicesSnap = await _firestore.collection('invoices').get();
      final paymentsSnap = await _firestore.collection('payments').get();

      final invoiceDocs = invoicesSnap.docs.map((d) => d.data()).toList();
      final paymentDocs = paymentsSnap.docs.map((d) => d.data()).toList();

      return ReportSummaryModel.fromInvoicesAndPayments(
        invoiceDocs: invoiceDocs,
        paymentDocs: paymentDocs,
      );
    });
  }
}
