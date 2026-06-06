import '../../../../core/config/app_config.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'firestore_inventory_repository.dart';
import 'mock_inventory_repository.dart';

class InventoryRepositoryFactory {
  static InventoryRepository make() {
    if (AppConfig.isTestingMode) {
      return MockInventoryRepository();
    } else {
      return FirestoreInventoryRepository();
    }
  }
}
