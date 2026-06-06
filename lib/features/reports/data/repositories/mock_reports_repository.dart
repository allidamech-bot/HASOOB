import 'dart:async';
import '../../domain/repositories/reports_repository.dart';
import '../models/report_summary_model.dart';

class MockReportsRepository implements ReportsRepository {
  final _controller = StreamController<ReportSummaryModel>.broadcast();

  MockReportsRepository() {
    _emitMockData();
  }

  void _emitMockData() {
    final mockSummary = ReportSummaryModel(
      totalRevenue: 4300.0,
      totalCollected: 2400.0,
      totalOverdue: 500.0,
      monthlySales: {
        'أبريل': 1200.0,
        'مايو': 1400.0,
        'يونيو': 1700.0,
      },
      topCustomers: [
        {'name': 'مؤسسة أحمد التجارية', 'value': 2900.0},
        {'name': 'شركة النور للتوريدات', 'value': 1400.0},
      ],
    );
    _controller.add(mockSummary);
  }

  @override
  Stream<ReportSummaryModel> getFinancialSummary() {
    Timer(const Duration(milliseconds: 300), _emitMockData);
    return _controller.stream;
  }
}
