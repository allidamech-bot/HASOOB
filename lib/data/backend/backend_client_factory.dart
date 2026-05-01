import '../../core/config/backend_config.dart';
import 'backend_client.dart';
import 'local_backend_client.dart';

class BackendClientFactory {
  static BackendClient create() {
    switch (BackendConfig.provider) {
      case BackendProvider.local:
        return LocalBackendClient();
      case BackendProvider.supabase:
        throw UnimplementedError("Supabase backend not connected yet");
      case BackendProvider.firebase:
        throw UnimplementedError("Firebase backend not connected yet");
    }
  }
}
