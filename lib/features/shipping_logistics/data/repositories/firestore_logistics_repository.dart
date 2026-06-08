import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/logistics_repository.dart';
import '../models/container_simulation_model.dart';

class FirestoreLogisticsRepository implements LogisticsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<ContainerSimulationModel> simulateContainerLoad({
    required Map<String, int> productQuantities,
    required String containerType,
    required double shippingCost,
    required double customsDuties,
  }) async {
    final docRef = _firestore.collection('shipping_simulations').doc();
    final totalCbm = containerType == '20ft' ? 33.2 : 67.7;
    
    final simulation = ContainerSimulationModel(
      containerType: containerType,
      totalVolumeCbm: totalCbm,
      usedVolumeCbm: 0.0,
      efficiencyPercentage: 0.0,
      totalLandedCost: shippingCost + customsDuties,
      remainingBoxCapacity: 0,
      currency: 'USD',
    );

    await docRef.set({
      ...simulation.toMap(),
      'productQuantities': productQuantities,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return simulation;
  }

  @override
  Future<double> calculateLandedCostPerUnit({
    required double itemBasePrice,
    required double itemVolumeCbm,
    required double totalShippingCost,
    required double totalCustomsDuties,
    required double totalBatchVolumeCbm,
  }) async {
    if (totalBatchVolumeCbm <= 0) return itemBasePrice;
    double allocatedCost = (totalShippingCost + totalCustomsDuties) * (itemVolumeCbm / totalBatchVolumeCbm);
    return itemBasePrice + allocatedCost;
  }
}
