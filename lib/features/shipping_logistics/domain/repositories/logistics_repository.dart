import '../../data/models/container_simulation_model.dart';

abstract class LogisticsRepository {
  Future<ContainerSimulationModel> simulateContainerLoad({
    required Map<String, int> productQuantities,
    required String containerType,
    required double shippingCost,
    required double customsDuties,
  });

  Future<double> calculateLandedCostPerUnit({
    required double itemBasePrice,
    required double itemVolumeCbm,
    required double totalShippingCost,
    required double totalCustomsDuties,
    required double totalBatchVolumeCbm,
  });
}
