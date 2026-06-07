import 'dart:async';
import '../../domain/repositories/prediction_repository.dart';
import '../models/cash_flow_prediction_model.dart';

class MockPredictionRepository implements PredictionRepository {
  @override
  Stream<List<CashFlowPredictionModel>> getRunwayForecast({int daysAhead = 90}) {
    final controller = StreamController<List<CashFlowPredictionModel>>();
    
    final List<CashFlowPredictionModel> mockForecast = List.generate(3, (index) {
      final futureDate = DateTime.now().add(Duration(days: (index + 1) * 30));
      double inflow = 45000.0 - (index * 5000);
      double outflow = 20000.0 + (index * 2000);
      double netPosition = 150000.0 + (inflow - outflow);
      
      return CashFlowPredictionModel(
        targetDate: futureDate,
        expectedInflow: inflow,
        expectedOutflow: outflow,
        netLiquidityPosition: netPosition,
        riskProbability: index == 2 ? 0.65 : 0.15,
        riskAlerts: index == 2 
          ? ['احتمالية تأخر تحصيل من عملاء رئيسيين في الرياض', 'مؤشر سيولة منخفض نسبياً'] 
          : [],
      );
    });

    Timer(const Duration(milliseconds: 300), () {
      controller.add(mockForecast);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<int> calculateCashRunwayDays() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 185; // 185 Days of safe cash runway remaining
  }
}
