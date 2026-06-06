import '../../../../core/config/app_config.dart';
import '../../domain/repositories/command_dock_repository.dart';
import 'firestore_command_dock_repository.dart';
import 'mock_command_dock_repository.dart';

class CommandDockRepositoryFactory {
  static CommandDockRepository make() {
    if (AppConfig.isTestingMode) {
      return MockCommandDockRepository();
    } else {
      return FirestoreCommandDockRepository();
    }
  }
}
