import '../database/database_helper.dart';

class BusinessProfileRepository {
  BusinessProfileRepository();

  Future<Map<String, dynamic>?> getBusinessProfile() async {
    return DBHelper.getBusinessProfile();
  }

  Future<void> saveBusinessProfile(Map<String, dynamic> profile) async {
    await DBHelper.saveBusinessProfile(profile);
  }
}
