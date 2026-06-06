import '../../data/models/dashboard_summary_model.dart';

abstract class DashboardRepository {
  Stream<DashboardSummaryModel> getDashboardSummary();
}
