import '../../../../core/config/app_config.dart';
import '../../domain/repositories/ai_accountant_repository.dart';
import 'firestore_ai_accountant_repository.dart';
import 'mock_ai_accountant_repository.dart';

class AiAccountantRepositoryFactory {
  static AiAccountantRepository make() {
    if (AppConfig.isTestingMode) {
      return MockAiAccountantRepository();
    } else {
      return FirestoreAiAccountantRepository();
    }
  }
}
