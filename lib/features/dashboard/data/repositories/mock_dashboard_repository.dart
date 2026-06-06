import 'dart:async';
import '../../domain/repositories/dashboard_repository.dart';
import '../models/dashboard_summary_model.dart';

class MockDashboardRepository implements DashboardRepository {
  final _controller = StreamController<DashboardSummaryModel>.broadcast();

  MockDashboardRepository() {
    _emitMockData();
  }

  void _emitMockData() {
    final mockSummary = DashboardSummaryModel(
      totalSalesVolume: 3800.0,
      activeCustomersCount: 3,
      lowStockItemsCount: 1,
      recoveryRate: 63.15,
      recentActivities: [
        {'title': 'تم تحصيل دفعة جديدة', 'subtitle': 'بقيمة 2400 ر.س من مؤسسة أحمد', 'time': 'منذ 5 دقائق'},
        {'title': 'تحديث المخزون', 'subtitle': 'شاشة 4K ذكية قاربت على النفاد (المتبقي: 8)', 'time': 'منذ ساعتين'},
        {'title': 'فواتير متأخرة', 'subtitle': 'مؤسسة أحمد تجاوزت تاريخ استحقاق الفاتورة #inv3', 'time': 'منذ 4 ساعات'},
      ],
    );
    _controller.add(mockSummary);
  }

  @override
  Stream<DashboardSummaryModel> getDashboardSummary() {
    Timer(const Duration(milliseconds: 300), _emitMockData);
    return _controller.stream;
  }
}
