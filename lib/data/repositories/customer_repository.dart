import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';

class CustomerRepository {
  Stream<List<Map<String, dynamic>>> watchCustomers(String businessId) {
    return CloudSyncService.instance
        .watchCustomers(businessId)
        .asyncMap((_) => DBHelper.getCustomers(businessId));
  }

  Future<List<Map<String, dynamic>>> getCustomers(String businessId) {
    return DBHelper.getCustomers(businessId);
  }

  Future<void> saveCustomer(String businessId, Map<String, dynamic> data) {
    return DBHelper.saveCustomer({
      ...data,
      'businessId': businessId,
    });
  }

  Future<Map<String, dynamic>> getCustomerStatement(String businessId, String customerId) {
    return DBHelper.getCustomerStatement(customerId, businessId);
  }
}
