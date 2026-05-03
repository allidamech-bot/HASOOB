import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_manager.dart';

class SmartSyncTriggerService {
  static SmartSyncTriggerService? _instance;
  static SmartSyncTriggerService get instance {
    if (_instance == null) {
      throw StateError('SmartSyncTriggerService must be initialized with a SyncManager first');
    }
    return _instance!;
  }

  static void init(SyncManager syncManager) {
    _instance = SmartSyncTriggerService(syncManager);
  }

  final SyncManager _syncManager;
  bool _isRunning = false;
  StreamSubscription? _connectivitySubscription;

  SmartSyncTriggerService(this._syncManager);

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.any((result) => result != ConnectivityResult.none)) {
        onConnectivityRestored();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> onAppStarted() async {
    await _runIfNeeded(force: false);
  }

  Future<void> onConnectivityRestored() async {
    await _runIfNeeded(force: false);
  }

  Future<void> onUserRequestedSync() async {
    await _runIfNeeded(force: true);
  }

  Future<void> onDataMutationQueued() async {
    await _runIfNeeded(force: false);
  }

  Future<void> _runIfNeeded({required bool force}) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      if (force) {
        await _syncManager.runSync();
      } else {
        final hasPending = await _syncManager.hasPendingOperations();
        final hasFailed = await _syncManager.hasFailedOperations();
        
        if (hasPending || hasFailed) {
          await _syncManager.runSync();
        }
      }
    } finally {
      _isRunning = false;
    }
  }
}
