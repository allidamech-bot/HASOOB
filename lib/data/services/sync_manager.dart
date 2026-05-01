import 'sync_engine.dart';

class SyncManager {
  static final instance = SyncManager._();
  SyncManager._();

  final _engine = SyncEngine();

  Future<void> runSync() async {
    await _engine.processQueue();
  }

  // Compatibility stubs for main.dart and DBHelper
  Future<void> initialize() async {}
  Future<void> onAuthenticated() async {}
  Future<void> onAppResumed() async {}
  Future<void> stopRealtimeSync() async {}
  Future<void> processQueue() async => await runSync();
}
