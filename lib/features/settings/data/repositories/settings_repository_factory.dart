import '../../../../core/config/app_config.dart';
import '../../domain/repositories/settings_repository.dart';
import 'firestore_settings_repository.dart';
import 'mock_settings_repository.dart';

class SettingsRepositoryFactory {
  static SettingsRepository make() {
    if (AppConfig.isTestingMode) {
      return MockSettingsRepository();
    } else {
      return FirestoreSettingsRepository();
    }
  }
}
