import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';

class CustomerRepository {
  Stream<List<Map<String, dynamic>>> watchCustomers() {
    return CloudSyncService.instance
        .watchCustomers()
        .asyncMap((_) => DBHelper.getCustomers());
  }

  Future<List<Map<String, dynamic>>> getCustomers() {
    return DBHelper.getCustomers();
  }

  Future<void> saveCustomer(Map<String, dynamic> data) {
    return DBHelper.saveCustomer(data);
  }

  Future<Map<String, dynamic>> getCustomerStatement(String customerId) {
    return DBHelper.getCustomerStatement(customerId);
  }
}
