import 'backend_client.dart';

class LocalBackendClient implements BackendClient {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<bool> get isConfigured async => true;

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_initialized) return null;
    // Mock local user for now
    return {
      'id': 'local-user-id',
      'email': 'local@example.com',
    };
  }

  @override
  Future<void> signOut() async {
    _initialized = false;
  }
}
