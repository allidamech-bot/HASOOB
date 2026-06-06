import '../../../../core/config/app_config.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'firestore_dashboard_repository.dart';
import 'mock_dashboard_repository.dart';

class DashboardRepositoryFactory {
  static DashboardRepository make() {
    if (AppConfig.isTestingMode) {
      return MockDashboardRepository();
    } else {
      return FirestoreDashboardRepository();
    }
  }
}
