import '../../domain/repositories/logistics_repository.dart';
import '../models/container_simulation_model.dart';

class MockLogisticsRepository implements LogisticsRepository {
  @override
  Future<ContainerSimulationModel> simulateContainerLoad({
    required Map<String, int> productQuantities,
    required String containerType,
    required double shippingCost,
    required double customsDuties,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    double totalVolumeUsed = 28.2; 
    double totalBaseCost = 24500.0;
    double landedCostTotal = totalBaseCost + shippingCost + customsDuties;
    double efficiency = (totalVolumeUsed / (containerType == '20ft' ? 33.2 : 67.7)) * 100;

    return ContainerSimulationModel(
      containerType: containerType,
      totalVolumeCbm: containerType == '20ft' ? 33.2 : 67.7,
      usedVolumeCbm: totalVolumeUsed,
      efficiencyPercentage: double.parse(efficiency.toStringAsFixed(1)),
      totalLandedCost: landedCostTotal,
      remainingBoxCapacity: containerType == '20ft' ? 48 : 120,
      currency: 'USD',
    );
  }

  @override
  Future<double> calculateLandedCostPerUnit({
    required double itemBasePrice,
    required double itemVolumeCbm,
    required double totalShippingCost,
    required double totalCustomsDuties,
    required double totalBatchVolumeCbm,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (totalBatchVolumeCbm <= 0) return itemBasePrice;
    
    double volumetricShare = itemVolumeCbm / totalBatchVolumeCbm;
    double allocatedCost = (totalShippingCost + totalCustomsDuties) * volumetricShare;
    return double.parse((itemBasePrice + allocatedCost).toStringAsFixed(2));
  }
}
