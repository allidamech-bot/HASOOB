import '../../data/models/user_settings_model.dart';

abstract class SettingsRepository {
  Stream<UserSettingsModel> getUserSettings(String email);
  Future<void> updateUserSettings(UserSettingsModel settings);
}
