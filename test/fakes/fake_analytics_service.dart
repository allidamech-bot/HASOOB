import 'package:hasoob_app/data/services/analytics_service.dart';

class FakeAnalyticsService implements AnalyticsService {
  final List<Map<String, dynamic>> events = [];

  @override
  Future<void> logEvent({required String name, Map<String, dynamic>? parameters}) async {
    events.add({'name': name, 'parameters': parameters});
  }

  @override
  Future<void> setUserProperty({required String name, required String? value}) async {
  }

  @override
  Future<void> setUserId(String? id) async {
  }

  @override
  Future<void> setCurrentScreen({required String screenName}) async {
  }
}
