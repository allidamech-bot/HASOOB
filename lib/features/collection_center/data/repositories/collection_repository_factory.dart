import '../../../../core/config/app_config.dart';
import '../../domain/repositories/collection_repository.dart';
import 'firestore_collection_repository.dart';
import 'mock_collection_repository.dart';

class CollectionRepositoryFactory {
  static CollectionRepository make() {
    if (AppConfig.isTestingMode) {
      return MockCollectionRepository();
    } else {
      return FirestoreCollectionRepository();
    }
  }
}
