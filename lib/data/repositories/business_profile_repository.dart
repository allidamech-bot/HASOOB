import '../database/database_helper.dart';
import '../models/business_model.dart';
import '../../core/business/business_context.dart';
import '../backend/backend_client.dart';
import '../backend/backend_client_factory.dart';

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
    await DBHelper.saveBusinessProfile(profile.toMap());
  }
}
