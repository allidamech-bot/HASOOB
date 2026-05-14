import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hasoob_app/data/services/firebase_bootstrap.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/data/services/smart_sync_trigger_service.dart';
import 'package:hasoob_app/data/services/auth_service.dart';
import 'package:hasoob_app/core/services/connectivity_service.dart';
import 'package:hasoob_app/core/utils/web_utils.dart';

enum StartupStatus {
  idle,
  initializing,
  ready,
  degraded,
  offline,
  failed,
}

class StartupCoordinator extends ChangeNotifier {
  static final StartupCoordinator instance = StartupCoordinator._();
  StartupCoordinator._();

  StartupStatus _status = StartupStatus.idle;
  StartupStatus get status => _status;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  FirebaseBootstrapResult? _firebaseResult;
  FirebaseBootstrapResult? get firebaseResult => _firebaseResult;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    final logMsg = '[$timestamp] $message';
    _logs.add(logMsg);
    debugPrint('[StartupCoordinator] $message');
    notifyListeners();
  }

  Future<void> start(FirebaseBootstrapResult initialFirebaseResult) async {
    if (_isInitialized) return;
    _isInitialized = true;
    _status = StartupStatus.initializing;
    _firebaseResult = initialFirebaseResult;
    _log('Startup started. Firebase configured: ${initialFirebaseResult.isConfigured}');

    // We run the rest of the initialization after a short delay to ensure first frame is rendered
    // and to avoid blocking the UI thread on heavy tasks.
    unawaited(_runInitialization());
  }

  Future<void> _runInitialization() async {
    try {
      // 1. Connectivity (Non-critical)
      await _guardedTask('Connectivity', () async {
        await ConnectivityService.instance.initialize().timeout(const Duration(seconds: 5));
      });

      // 2. Sync & Services (Critical for cloud functionality, but non-blocking for UI)
      if (_firebaseResult?.isConfigured == true) {
        await _guardedTask('Sync & Auth', () async {
          // Initialize SyncManager
          await SyncManager.instance.initialize().timeout(const Duration(seconds: 10));

          // Initialize SmartSync
          SmartSyncTriggerService.init(SyncManager.instance);
          SmartSyncTriggerService.instance.initialize();

          if (kIsWeb) {
            WebUtils.registerSyncLifecycleHook((eventName) {
              _guardedTask('Lifecycle Sync ($eventName)', () async {
                await SyncManager.instance.onLifecycleSignal(eventName);
              });
            });
          }

          // Initial sync run
          unawaited(SyncManager.instance.runSync());

          // Setup Auth listener for sync
          AuthService.instance.authStateChanges().listen((user) {
            if (user != null) {
              _guardedTask('Auth Login Sync', () async {
                await SyncManager.instance.onAuthenticated();
                await SmartSyncTriggerService.instance.onAppStarted();
              });
            } else {
              _guardedTask('Auth Logout Sync', () async {
                await SyncManager.instance.stopRealtimeSync();
              });
            }
          }, onError: (e) {
            _log('Auth listener error: $e');
          });
        });
      } else {
        _log('Sync initialization skipped: Firebase not configured');
        _status = StartupStatus.degraded;
      }

      if (_status == StartupStatus.initializing) {
        _status = StartupStatus.ready;
      }
      _log('Startup initialization completed. Status: $_status');
    } catch (e, st) {
      _log('Startup critical failure: $e');
      debugPrint(st.toString());
      _status = StartupStatus.failed;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _guardedTask(String name, Future<void> Function() task) async {
    _log('Starting task: $name');
    try {
      await task();
      _log('Task completed: $name');
    } catch (e, st) {
      _log('Task failed: $name. Error: $e');
      debugPrint(st.toString());
    }
  }
}
