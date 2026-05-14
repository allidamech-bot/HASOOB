import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/services/startup_coordinator.dart';
import 'package:hasoob_app/data/services/firebase_bootstrap.dart';

void main() {
  group('StartupCoordinator Tests', () {
    test('initial status is idle', () {
      final coordinator = StartupCoordinator.instance;
      expect(coordinator.status, StartupStatus.idle);
      expect(coordinator.isInitialized, false);
    });

    test('start changes status to initializing', () async {
      final coordinator = StartupCoordinator.instance;
      const firebaseResult = FirebaseBootstrapResult(
        isConfigured: true,
        message: 'Test',
        selectedPlatform: 'test',
        webConfigExists: true,
      );

      // ignore: unawaited_futures
      coordinator.start(firebaseResult);
      
      expect(coordinator.isInitialized, true);
      expect(coordinator.status, StartupStatus.initializing);
      expect(coordinator.firebaseResult, firebaseResult);
    });

    // Since _runInitialization is unawaited and internal, 
    // we might need to wait for it to complete in a real test scenario.
    // However, since it depends on many singleton services (SyncManager, etc.),
    // it's hard to test in isolation without heavy mocking.
  });
}
