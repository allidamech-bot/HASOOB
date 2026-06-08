import '../../../../core/config/app_config.dart';
import '../../domain/repositories/logistics_repository.dart';
import 'firestore_logistics_repository.dart';
import 'mock_logistics_repository.dart';

class LogisticsRepositoryFactory {
  static LogisticsRepository make() {
    if (AppConfig.isTestingMode) {
      return MockLogisticsRepository();
    } else {
      return FirestoreLogisticsRepository();
    }
  }
}
