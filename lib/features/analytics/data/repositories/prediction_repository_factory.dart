import '../../../../core/config/app_config.dart';
import '../../domain/repositories/prediction_repository.dart';
import 'firestore_prediction_repository.dart';
import 'mock_prediction_repository.dart';

class PredictionRepositoryFactory {
  static PredictionRepository make() {
    if (AppConfig.isTestingMode) {
      return MockPredictionRepository();
    } else {
      return FirestorePredictionRepository();
    }
  }
}
