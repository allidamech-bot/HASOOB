import '../../../../core/config/app_config.dart';
import '../../domain/repositories/customer_repository.dart';
import 'firestore_customer_repository.dart';
import 'mock_customer_repository.dart';

class CustomerRepositoryFactory {
  static CustomerRepository make() {
    if (AppConfig.isTestingMode) {
      return MockCustomerRepository();
    } else {
      return FirestoreCustomerRepository();
    }
  }
}
