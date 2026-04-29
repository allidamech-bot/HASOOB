import '../database/database_helper.dart';
import '../models/business_model.dart';

class BusinessProfileRepository {
  BusinessProfileRepository();

  Future<BusinessModel?> getBusinessProfile() async {
    final data = await DBHelper.getBusinessProfile();
    return data != null ? BusinessModel.fromMap(data) : null;
  }

  Future<void> saveBusinessProfile(BusinessModel profile) async {
    await DBHelper.saveBusinessProfile(profile.toMap());
  }
}
