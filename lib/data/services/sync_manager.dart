import 'sync_engine.dart';

class SyncManager {
  static final instance = SyncManager._();
  SyncManager._();

  final _engine = SyncEngine();
  bool _isRunning = false;
  bool _syncRequested = false;

  bool get syncRequested => _syncRequested;

  void requestSync() {
    _syncRequested = true;
  }

  Future<void> runSync() async {
    _syncRequested = false;
    if (_isRunning) return;
    _isRunning = true;

    try {
      await _engine.processQueue();
    } finally {
      _isRunning = false;
    }
  }

  // Compatibility stubs for main.dart and DBHelper
  Future<void> initialize() async {}
  Future<void> onAuthenticated() async {}
  Future<void> onAppResumed() async {}
  Future<void> stopRealtimeSync() async {}
  Future<void> processQueue() async => await runSync();
}
