abstract class BackendClient {
  Future<void> initialize();
  Future<bool> get isConfigured;
  Future<Map<String, dynamic>?> getCurrentUser();
  Future<void> signOut();
}
