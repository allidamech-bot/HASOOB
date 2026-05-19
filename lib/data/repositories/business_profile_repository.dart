import '../database/database_helper.dart';
import '../models/business_model.dart';
import '../../core/business/business_context.dart';
import '../backend/backend_client.dart';
import '../backend/backend_client_factory.dart';
import '../services/sync_queue_service.dart';
import '../models/sync_operation.dart';

class BusinessProfileRepository {
  final BackendClient backendClient;

  BusinessProfileRepository({BackendClient? backendClient})
      : backendClient = backendClient ?? BackendClientFactory.create();

  String get _currentBusinessId => BusinessContext.businessId;

  Future<BusinessModel?> getBusinessProfile([String? businessId]) async {
    final data = await DBHelper.getBusinessProfile(businessId ?? _currentBusinessId);
    return data != null ? BusinessModel.fromMap(data) : null;
  }

  Future<void> saveBusinessProfile(BusinessModel profile) async {
    final businessId = _currentBusinessId;
    final data = profile.toMap();
    // Ensure businessId is set correctly
    data['businessId'] = businessId;
    data['id'] = businessId;
    await DBHelper.saveBusinessProfile(data);
    
    // Enqueue sync operation
    await SyncQueueService.instance.enqueue(
      entityName: 'business_profile',
      entityId: '1',
      type: SyncOperationType.update,
      payload: data,
      priority: 2,
    );
  }
}
