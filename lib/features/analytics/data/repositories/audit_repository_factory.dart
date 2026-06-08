import '../../../../core/config/app_config.dart';
import '../../domain/repositories/audit_repository.dart';
import 'firestore_audit_repository.dart';
import 'mock_audit_repository.dart';

class AuditRepositoryFactory {
  static AuditRepository make() {
    if (AppConfig.isTestingMode) {
      return MockAuditRepository();
    } else {
      return FirestoreAuditRepository();
    }
  }
}
