class ContainerSimulationModel {
  final String containerType; // '20ft' | '40ft'
  final double totalVolumeCbm; 
  final double usedVolumeCbm;
  final double efficiencyPercentage; 
  final double totalLandedCost;
  final int remainingBoxCapacity;
  final String currency;

  ContainerSimulationModel({
    required this.containerType,
    required this.totalVolumeCbm,
    required this.usedVolumeCbm,
    required this.efficiencyPercentage,
    required this.totalLandedCost,
    required this.remainingBoxCapacity,
    required this.currency,
  });

  factory ContainerSimulationModel.fromMap(Map<String, dynamic> map) {
    return ContainerSimulationModel(
      containerType: map['containerType'] ?? '20ft',
      totalVolumeCbm: (map['totalVolumeCbm'] ?? 33.2).toDouble(),
      usedVolumeCbm: (map['usedVolumeCbm'] ?? 0.0).toDouble(),
      efficiencyPercentage: (map['efficiencyPercentage'] ?? 0.0).toDouble(),
      totalLandedCost: (map['totalLandedCost'] ?? 0.0).toDouble(),
      remainingBoxCapacity: (map['remainingBoxCapacity'] ?? 0).toInt(),
      currency: map['currency'] ?? 'USD',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'containerType': containerType,
      'totalVolumeCbm': totalVolumeCbm,
      'usedVolumeCbm': usedVolumeCbm,
      'efficiencyPercentage': efficiencyPercentage,
      'totalLandedCost': totalLandedCost,
      'remainingBoxCapacity': remainingBoxCapacity,
      'currency': currency,
    };
  }
}
