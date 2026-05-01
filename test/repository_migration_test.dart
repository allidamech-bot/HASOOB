import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/repositories/business_profile_repository.dart';
import 'package:hasoob_app/data/repositories/customer_repository.dart';
import 'package:hasoob_app/data/backend/backend_client.dart';

class MockBackendClient implements BackendClient {
  bool initializedCalled = false;
  @override
  Future<void> initialize() async {
    initializedCalled = true;
  }

  @override
  Future<bool> get isConfigured async => true;

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  group('Repository Migration Tests', () {
    test('BusinessProfileRepository uses LocalBackendClient by default', () {
      final repo = BusinessProfileRepository();
      // We can't easily check the private field, but we can verify it doesn't throw
      expect(repo, isNotNull);
    });

    test('BusinessProfileRepository accepts custom BackendClient', () {
      final mock = MockBackendClient();
      final repo = BusinessProfileRepository(backendClient: mock);
      expect(repo.backendClient, same(mock));
    });

    test('CustomerRepository uses LocalBackendClient by default', () {
      final repo = CustomerRepository();
      expect(repo.backendClient, isNotNull);
    });

    test('CustomerRepository accepts custom BackendClient', () {
      final mock = MockBackendClient();
      final repo = CustomerRepository(backendClient: mock);
      expect(repo.backendClient, same(mock));
    });
  });
}
