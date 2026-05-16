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
  bool _isCloudAvailable = true;
  String? _lastSyncError;

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
  bool get isCloudAvailable => _isCloudAvailable;
  String? get lastSyncError => _lastSyncError;

  /// Resets the singleton state for testing purposes.
  @visibleForTesting
  void resetForTest() {
    _isRunning = false;
    _syncRequested = false;
    _isCloudAvailable = true;
    _lastSyncError = null;
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

  void markCloudUnavailable({String? error}) {
    if (_isCloudAvailable) {
      _isCloudAvailable = false;
      _lastSyncError = error;
      notifyListeners();
    }
  }

  void markCloudAvailable() {
    if (!_isCloudAvailable) {
      _isCloudAvailable = true;
      _lastSyncError = null;
      notifyListeners();
    }
  }

  DateTime? _lastSyncTime;

  Future<void> runSync({bool force = false}) async {
    if (_isRunning) {
      _syncRequested = true;
      return;
    }

    try {
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

      await _engine.processQueue();
      _lastSyncTime = DateTime.now();
      _isCloudAvailable = true;
      _lastSyncError = null;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[Sync] sync failed: $e');
      _lastSyncError = e.toString();
      if (e.toString().contains('permission-denied')) {
        _isCloudAvailable = false;
      }
      _syncRequested = true;
      notifyListeners();
    } finally {
      if (_isRunning) {
        _isRunning = false;
        notifyListeners();
      }
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        BusinessContext.initialize(
          businessId: user.uid,
          userId: user.uid,
          role: 'owner',
        );
        await runSync();
      }
    } catch (e, stack) {
      debugPrint('[Sync] onAuthenticated failed: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> onAppResumed() async {
    try {
      await SyncQueueService.instance.recoverInterruptedProcessing();
      await runSync();
    } catch (e, stack) {
      debugPrint('[Sync] onAppResumed failed: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> onAppPausing() async {
    try {
      await SyncQueueService.instance.flushPendingLocalWrites();
      if (!_isRunning) {
        await runSync();
      }
    } catch (e, stack) {
      debugPrint('[Sync] onAppPausing failed: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> onLifecycleSignal(String eventName) async {
    if (!_isInitialized) return;

    try {
      switch (eventName) {
        case 'visible':
        case 'focus':
        case 'pageshow':
        case 'online':
          await onAppResumed();
          break;
        case 'hidden':
        case 'blur':
        case 'pagehide':
          await onAppPausing();
          break;
        case 'offline':
          debugPrint('[Sync] offline signal');
          break;
        default:
          break;
      }
    } catch (e, stack) {
      debugPrint('[Sync] Lifecycle signal ($eventName) processing failed: $e');
      debugPrint(stack.toString());
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
