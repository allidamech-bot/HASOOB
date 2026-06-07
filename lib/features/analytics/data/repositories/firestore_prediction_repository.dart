import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/prediction_repository.dart';
import '../models/cash_flow_prediction_model.dart';

class FirestorePredictionRepository implements PredictionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<CashFlowPredictionModel>> getRunwayForecast({int daysAhead = 90}) {
    // Aggregates real-time values from dynamic cloud function predictive algorithms
    return _firestore.collection('financial_forecasts')
        .orderBy('targetDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CashFlowPredictionModel.fromMap(doc.data()))
            .toList());
  }

  @override
  Future<int> calculateCashRunwayDays() async {
    final meta = await _firestore.collection('financial_metadata').doc('runway').get();
    if (!meta.exists || meta.data() == null) return 365;
    return meta.data()!['daysRemaining'] ?? 365;
  }
}
