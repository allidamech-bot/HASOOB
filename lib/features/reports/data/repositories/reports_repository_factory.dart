import '../../../../core/config/app_config.dart';
import '../../domain/repositories/reports_repository.dart';
import 'firestore_reports_repository.dart';
import 'mock_reports_repository.dart';

class ReportsRepositoryFactory {
  static ReportsRepository make() {
    if (AppConfig.isTestingMode) {
      return MockReportsRepository();
    } else {
      return FirestoreReportsRepository();
    }
  }
}
