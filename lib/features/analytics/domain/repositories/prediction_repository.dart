import '../../data/models/cash_flow_prediction_model.dart';

abstract class PredictionRepository {
  /// يحلل البيانات المالية التاريخية ويولد محاكاة تدفق نقدي للمستقبل
  Stream<List<CashFlowPredictionModel>> getRunwayForecast({int daysAhead = 90});
  
  /// يحسب عدد الأيام المتبقية قبل نفاد السيولة النقدية بناءً على معدل الحرق الحالي
  Future<int> calculateCashRunwayDays();
}
