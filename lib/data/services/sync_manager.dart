import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/business/business_context.dart';
import 'sync_engine.dart';
import 'sync_queue_service.dart';
import 'analytics_service.dart';
import 'firebase_backend_adapter.dart';
import '../repositories/sync_queue_repository.dart';
import '../models/sync_operation.dart';

class SyncManager extends ChangeNotifier {
  static final instance = SyncManager._();
  SyncManager._();

  SyncEngine _engine = SyncEngine();
  bool _isRunning = false;
  bool _syncRequested = false;
  bool _isInitialized = false;

  /// Allows injecting a custom engine for testing.
  @visibleForTesting
  void setEngine(SyncEngine engine) {
    _engine = engine;
  }

  SyncEngine get engine => _engine;

  bool get isRunning => _isRunning;
  bool get syncRequested => _syncRequested;

  void requestSync() {
    if (!_syncRequested) {
      _syncRequested = true;
      debugPrint('[Sync] sync requested');
      notifyListeners();
    }
  }

  Future<void> runSync() async {
    _syncRequested = false;
    if (_isRunning) return;

    final queueLength = await SyncQueueService.instance.pendingQueueLength();
    debugPrint('[Sync] queue length before sync=$queueLength');
    if (queueLength == 0) {
      debugPrint('[Sync] sync skipped: queue empty');
      return;
    }

    if (!await _hasAuthenticatedUser()) {
      debugPrint('[Sync] Cloud sync unavailable until sign-in/Firebase is ready');
      requestSync();
      return;
    }

    if (!await _isOnline()) {
      debugPrint('[Sync] sync deferred: offline');
      requestSync();
      return;
    }

    _isRunning = true;
    notifyListeners();

    try {
      debugPrint('[Sync] sync started');
      await _engine.processQueue();
      final remaining = await SyncQueueService.instance.pendingQueueLength();
      debugPrint('[Sync] sync completed; remainingQueueLength=$remaining');
    } catch (e) {
      debugPrint('[Sync] sync failed/retry scheduled: $e');
      requestSync();
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

  /// Runs sync only if it was previously requested.
  Future<void> runIfRequested() async {
    if (!_syncRequested) return;
    await runSync();
  }

  /// Manually notify listeners (used by other services to trigger UI updates)
  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  // Compatibility stubs for main.dart and DBHelper
  Future<void> initialize() async {
    // In production, we wire up the real Firebase Analytics and Backend Adapter
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
      debugPrint('[Sync] auth ready uid=${user.uid}');
      BusinessContext.initialize(
        businessId: user.uid, // Using UID as businessId for now as a stable ID
        userId: user.uid,
        role: 'owner',
      );
      
      // Process pending queue after authentication
      await runSync();
    }
  }

  Future<void> onAppResumed() async {
    debugPrint('[Sync] app resumed');
    await SyncQueueService.instance.recoverInterruptedProcessing();
    await runSync();
  }

  Future<void> onAppPausing() async {
    debugPrint('[Sync] app pausing/page hidden');
    await SyncQueueService.instance.flushPendingLocalWrites();
    if (!_isRunning) {
      await runSync();
    }
  }

  Future<void> onLifecycleSignal(String eventName) async {
    if (!_isInitialized) {
      debugPrint('[Sync] lifecycle $eventName ignored: sync not initialized');
      return;
    }

    debugPrint('[Sync] lifecycle event=$eventName');
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
        debugPrint('[Sync] sync deferred: browser offline');
      default:
        debugPrint('[Sync] lifecycle event ignored: $eventName');
    }
  }

  Future<void> stopRealtimeSync() async {
    // Safely stop/reset realtime listeners if any exist.
    // Currently CloudSyncService handles streams directly in UI, 
    // but if we had background listeners, we'd cancel them here.
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
      debugPrint('[Sync] auth unavailable: $e');
      return false;
    }
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((entry) => entry != ConnectivityResult.none);
    } catch (e) {
      debugPrint('[Sync] connectivity check failed, attempting sync anyway: $e');
      return true;
    }
  }
}
