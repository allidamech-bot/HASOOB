import '../../data/models/report_summary_model.dart';

abstract class ReportsRepository {
  Stream<ReportSummaryModel> getFinancialSummary();
}
