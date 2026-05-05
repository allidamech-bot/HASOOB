import 'package:hasoob_app/data/services/analytics_service.dart';

class FakeAnalyticsService implements AnalyticsService {
  final List<Map<String, dynamic>> events = [];

  @override
  Future<void> logEvent({required String name, Map<String, Object>? parameters}) async {
    events.add({'name': name, 'parameters': parameters});
  }
}
