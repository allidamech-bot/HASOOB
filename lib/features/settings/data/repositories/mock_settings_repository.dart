import 'dart:async';
import '../../domain/repositories/settings_repository.dart';
import '../models/user_settings_model.dart';

class MockSettingsRepository implements SettingsRepository {
  final _controller = StreamController<UserSettingsModel>.broadcast();
  
  UserSettingsModel _currentSettings = UserSettingsModel(
    email: 'owner@hasoob.com',
    role: 'owner',
    permissions: {
      'canEditInventory': true,
      'canViewReports': true,
      'canManageInvoices': true,
    },
  );

  MockSettingsRepository() {
    _controller.add(_currentSettings);
  }

  @override
  Stream<UserSettingsModel> getUserSettings(String email) {
    Timer(const Duration(milliseconds: 200), () => _controller.add(_currentSettings));
    return _controller.stream;
  }

  @override
  Future<void> updateUserSettings(UserSettingsModel settings) async {
    _currentSettings = settings;
    _controller.add(_currentSettings);
  }
}
