import '../database/database_helper.dart';
import '../models/business_model.dart';
import '../../core/business/business_context.dart';

class BusinessProfileRepository {
  BusinessProfileRepository();

  String get _currentBusinessId => BusinessContext.businessId;

  Future<BusinessModel?> getBusinessProfile([String? businessId]) async {
    final data = await DBHelper.getBusinessProfile(businessId ?? _currentBusinessId);
    return data != null ? BusinessModel.fromMap(data) : null;
  }

  Future<void> saveBusinessProfile(BusinessModel profile) async {
    await DBHelper.saveBusinessProfile(profile.toMap());
  }
}
