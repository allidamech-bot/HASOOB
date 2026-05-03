import 'package:flutter/foundation.dart';
import 'sync_engine.dart';

class SyncManager extends ChangeNotifier {
  static final instance = SyncManager._();
  SyncManager._();

  SyncEngine _engine = SyncEngine();
  bool _isRunning = false;
  bool _syncRequested = false;

  /// Allows injecting a custom engine for testing.
  @visibleForTesting
  void setEngine(SyncEngine engine) {
    _engine = engine;
  }

  bool get isRunning => _isRunning;
  bool get syncRequested => _syncRequested;

  void requestSync() {
    if (!_syncRequested) {
      _syncRequested = true;
      notifyListeners();
    }
  }

  Future<void> runSync() async {
    _syncRequested = false;
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();

    try {
      await _engine.processQueue();
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Runs sync only if it was previously requested.
  Future<void> runIfRequested() async {
    if (!_syncRequested) return;
    await runSync();
  }

  // Compatibility stubs for main.dart and DBHelper
  Future<void> initialize() async {}
  Future<void> onAuthenticated() async {}
  Future<void> onAppResumed() async {}
  Future<void> stopRealtimeSync() async {}
  Future<void> processQueue() async => await runSync();
}
