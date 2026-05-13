import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/data/services/sync_engine.dart';
import 'package:hasoob_app/data/services/sync_queue_service.dart';
import 'package:hasoob_app/data/services/analytics_service.dart';
import 'package:hasoob_app/data/services/firebase_backend_adapter.dart';
import 'package:hasoob_app/data/repositories/sync_queue_repository.dart';
import 'package:hasoob_app/data/models/sync_operation.dart';

class SyncManager extends ChangeNotifier {
  static final instance = SyncManager._();
  SyncManager._();

  SyncEngine _engine = SyncEngine();
  bool _isRunning = false;
  bool _syncRequested = false;
  bool _isInitialized = false;
  bool _isTestMode = false;

  /// Allows injecting a custom engine for testing.
  @visibleForTesting
  void setEngine(SyncEngine engine) {
    _engine = engine;
    _isTestMode = true;
  }

  SyncEngine get engine => _engine;
  bool get isTestMode => _isTestMode;

  bool get isRunning => _isRunning;
  bool get syncRequested => _syncRequested;

  /// Resets the singleton state for testing purposes.
  @visibleForTesting
  void resetForTest() {
    _isRunning = false;
    _syncRequested = false;
    _lastSyncTime = null;
    _isTestMode = true;
    _engine = SyncEngine();
    _isInitialized = true;
  }

  void requestSync() {
    if (!_syncRequested) {
      _syncRequested = true;
      debugPrint('[Sync] sync requested');
      notifyListeners();
    }
  }

  DateTime? _lastSyncTime;

  Future<void> runSync({bool force = false}) async {
    if (_isRunning) {
      _syncRequested = true;
      return;
    }

    final now = DateTime.now();
    final isThrottled = !force && !_isTestMode && _lastSyncTime != null && now.difference(_lastSyncTime!).inSeconds < 15;
    
    if (isThrottled) {
      debugPrint('[Sync] sync throttled');
      return;
    }

    final queueLength = await SyncQueueService.instance.pendingQueueLength();
    if (queueLength == 0) {
      _syncRequested = false;
      return;
    }

    if (!_isTestMode && !await _hasAuthenticatedUser()) {
      debugPrint('[Sync] Cloud sync unavailable: no auth');
      return;
    }

    if (!await _isOnline()) {
      debugPrint('[Sync] sync deferred: offline');
      return;
    }

    _isRunning = true;
    _syncRequested = false;
    notifyListeners();

    try {
      await _engine.processQueue();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('[Sync] sync failed: $e');
      _syncRequested = true;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<bool> hasPendingOperations() async {
    final operations = await SyncQueueService.instance.getPending();
    return operations.isNotEmpty;
  }

  Future<bool> hasFailedOperations() async {
    final all = await SyncQueueRepository().getAllOperations();
    return all.any((op) => op.status == SyncStatus.failed);
  }

  Future<bool> isQueueEmpty() async {
    final all = await SyncQueueRepository().getAllOperations();
    return all.isEmpty;
  }

  Future<void> runIfRequested() async {
    if (!_syncRequested) return;
    await runSync();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  Future<void> initialize() async {
    _engine = SyncEngine(
      analytics: FirebaseAnalyticsService(),
      backendAdapter: FirebaseBackendAdapter(),
    );
    _isInitialized = true;
    await SyncQueueService.instance.recoverInterruptedProcessing();
  }

  Future<void> onAuthenticated() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      BusinessContext.initialize(
        businessId: user.uid,
        userId: user.uid,
        role: 'owner',
      );
      await runSync();
    }
  }

  Future<void> onAppResumed() async {
    await SyncQueueService.instance.recoverInterruptedProcessing();
    await runSync();
  }

  Future<void> onAppPausing() async {
    await SyncQueueService.instance.flushPendingLocalWrites();
    if (!_isRunning) {
      await runSync();
    }
  }

  Future<void> onLifecycleSignal(String eventName) async {
    if (!_isInitialized) return;

    switch (eventName) {
      case 'visible':
      case 'focus':
      case 'pageshow':
      case 'online':
        await onAppResumed();
      case 'hidden':
      case 'blur':
      case 'pagehide':
        await onAppPausing();
      case 'offline':
        debugPrint('[Sync] offline signal');
      default:
        break;
    }
  }

  Future<void> stopRealtimeSync() async {
    _isRunning = false;
    _syncRequested = false;
    notifyListeners();
  }

  Future<void> processQueue() async => await runSync();

  Future<bool> _hasAuthenticatedUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((entry) => entry != ConnectivityResult.none);
    } catch (e) {
      return true;
    }
  }
}
