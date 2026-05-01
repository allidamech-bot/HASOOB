import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/backend/backend_client_factory.dart';
import 'package:hasoob_app/data/backend/local_backend_client.dart';

void main() {
  group('BackendClient', () {
    test('LocalBackendClient initializes', () async {
      final client = LocalBackendClient();
      await client.initialize();
      final user = await client.getCurrentUser();
      expect(user, isNotNull);
      expect(user?['id'], 'local-user-id');
    });

    test('LocalBackendClient is configured', () async {
      final client = LocalBackendClient();
      expect(await client.isConfigured, isTrue);
    });

    test('BackendClientFactory returns local client when provider is local', () {
      final client = BackendClientFactory.create();
      expect(client, isA<LocalBackendClient>());
    });
  });
}
