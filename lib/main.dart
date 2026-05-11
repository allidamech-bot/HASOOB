// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';
import 'dart:io' as io;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/app_locale_controller.dart';
import 'core/app_theme.dart';
import 'core/app_theme_controller.dart';
import 'data/services/auth_service.dart';
import 'data/services/firebase_bootstrap.dart';
import 'data/services/sync_manager.dart';
import 'data/services/smart_sync_trigger_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/sync_center_screen.dart';
import 'core/services/connectivity_service.dart';
import 'core/utils/web_utils.dart';

enum StartupStage {
  appStart('Starting...'),
  bindingInit('Binding Flutter...'),
  dateInit('Initializing Date Format...'),
  sqfliteWebInit('Initializing Web Database (WASM)...'),
  databaseInit('Connecting to Database...'),
  connectivityInit('Checking Network...'),
  firebaseInit('Initializing Firebase...'),
  controllersInit('Loading Theme/Locale...'),
  analyticsInit('Setting up Analytics...'),
  syncInit('Starting Sync Engine...'),
  running('Running');

  final String label;
  const StartupStage(this.label);
}

class StartupDiagnostic {
  static final instance = StartupDiagnostic._();
  StartupDiagnostic._();

  final ValueNotifier<StartupStage> stage = ValueNotifier(StartupStage.appStart);
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  final ValueNotifier<bool> degradedSync = ValueNotifier(false);
  final ValueNotifier<String?> lastLog = ValueNotifier('App started');
  Timer? _timer;
  Timer? _watchdog;
  String? lastTrace;

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds.value = timer.tick;
    });

    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (stage.value != StartupStage.running && error.value == null) {
        fail(
          'Startup Watchdog Triggered: App hung for >15s at stage ${stage.value.name}. '
          'Last log: ${lastLog.value}',
          StackTrace.current,
        );
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _watchdog?.cancel();
  }

  void logStage(StartupStage newStage) {
    final msg = '[Startup] [${elapsedSeconds.value}s] === STAGE: ${newStage.name} ===';
    debugPrint(msg);
    lastLog.value = msg;
    stage.value = newStage;
  }

  void fail(dynamic e, StackTrace stack) {
    stopTimer();
    final errorMsg = e.toString();
    debugPrint('[Startup] !!! FAILED at stage ${stage.value.name}: $errorMsg');
    debugPrint(stack.toString());
    lastTrace = stack.toString();
    error.value = 'Failed at ${stage.value.name}: $errorMsg';
  }
}

Future<void> main() async {
  StartupDiagnostic.instance.startTimer();

  // Global error catching for async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    StartupDiagnostic.instance.fail(error, stack);
    return true;
  };

  // Global error catching for Flutter errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    StartupDiagnostic.instance.fail(details.exception, details.stack ?? StackTrace.current);
  };

  try {
    StartupDiagnostic.instance.logStage(StartupStage.bindingInit);
    WidgetsFlutterBinding.ensureInitialized();

    StartupDiagnostic.instance.logStage(StartupStage.dateInit);
    await initializeDateFormatting().timeout(const Duration(seconds: 5));

    debugPrint('[Startup] Environment: kIsWeb=$kIsWeb, Platform=${defaultTargetPlatform.name}');

    // Minimal critical DB setup (Windows only, Web is delayed)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      StartupDiagnostic.instance.logStage(StartupStage.databaseInit);
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    StartupDiagnostic.instance.logStage(StartupStage.firebaseInit);
    final bootstrapResult = await FirebaseBootstrap.initialize().timeout(const Duration(seconds: 10));

    StartupDiagnostic.instance.logStage(StartupStage.controllersInit);
    final themeController = await AppThemeController.load().timeout(const Duration(seconds: 5));
    final localeController = await AppLocaleController.load().timeout(const Duration(seconds: 5));

    runApp(
      HasoobApp(
        bootstrapResult: bootstrapResult,
        themeController: themeController,
        localeController: localeController,
      ),
    );
  } catch (e, st) {
    debugPrint('[Startup] CRITICAL STARTUP ERROR: $e');
    StartupDiagnostic.instance.fail(e, st);
    
    // Fallback to error app if main bootstrap fails
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class HasoobApp extends StatefulWidget {
  const HasoobApp({
    super.key,
    required this.bootstrapResult,
    required this.themeController,
    required this.localeController,
  });

  final FirebaseBootstrapResult bootstrapResult;
  final AppThemeController themeController;
  final AppLocaleController localeController;

  @override
  State<HasoobApp> createState() => _HasoobAppState();
}

class _HasoobAppState extends State<HasoobApp> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _authSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start post-frame initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _completeStartup();
    });
  }

  Future<void> _completeStartup() async {
    // 1. Signal first frame to JS and remove native splash
    WebUtils.logDiagnostic('first Flutter frame rendered');
    WebUtils.removeSplash();

    // 2. Web Database (WASM) - Heavy initialization delayed until after first frame
    if (kIsWeb) {
      try {
        StartupDiagnostic.instance.logStage(StartupStage.sqfliteWebInit);
        databaseFactory = await Future.sync(() {
          return createDatabaseFactoryFfiWeb(
            options: SqfliteFfiWebOptions(
              sqlite3WasmUri: Uri.parse('sqlite3.wasm'),
              // ignore: invalid_use_of_visible_for_testing_member
              forceAsBasicWorker: defaultTargetPlatform == TargetPlatform.iOS,
            ),
          );
        }).timeout(const Duration(seconds: 20), onTimeout: () {
          throw TimeoutException('SQLite WASM initialization timed out after 20s');
        });
        debugPrint('[Startup] Web Database Factory set.');
      } catch (e, st) {
        StartupDiagnostic.instance.fail('Web DB Init: $e', st);
        return;
      }
    }

    // 3. Connectivity Service
    StartupDiagnostic.instance.logStage(StartupStage.connectivityInit);
    try {
      await ConnectivityService.instance.initialize().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[Startup] Non-critical Connectivity error: $e');
    }

    // 4. Firebase Analytics
    if (widget.bootstrapResult.isConfigured) {
      StartupDiagnostic.instance.logStage(StartupStage.analyticsInit);
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true).timeout(const Duration(seconds: 3));
        await FirebaseAnalytics.instance.logEvent(name: 'app_open_custom').timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[Startup] Non-critical Analytics error: $e');
      }
    }

    // 5. Sync & Services
    StartupDiagnostic.instance.logStage(StartupStage.syncInit);
    try {
      // Initialize SyncManager
      await SyncManager.instance.initialize().timeout(const Duration(seconds: 10));
      
      // Initialize SmartSync
      SmartSyncTriggerService.init(SyncManager.instance);
      SmartSyncTriggerService.instance.initialize();
      unawaited(SmartSyncTriggerService.instance.onAppStarted());

      // Setup Auth listener
      _authSubscription = AuthService.instance.authStateChanges().listen((user) {
        if (user != null) {
          unawaited(SyncManager.instance.onAuthenticated());
          unawaited(SmartSyncTriggerService.instance.onAppStarted());
        } else {
          unawaited(SyncManager.instance.stopRealtimeSync());
        }
      });
    } catch (e) {
      debugPrint('[Startup] Sync initialization error: $e');
      StartupDiagnostic.instance.degradedSync.value = true;
    }

    // 6. Complete
    StartupDiagnostic.instance.logStage(StartupStage.running);
    StartupDiagnostic.instance.stopTimer();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      try {
        SmartSyncTriggerService.instance.dispose();
      } catch (_) {}
    }
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isInitialized) {
      unawaited(SyncManager.instance.onAppResumed());
      unawaited(SmartSyncTriggerService.instance.onAppStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeControllerScope(
      controller: widget.themeController,
      child: AppLocaleControllerScope(
        controller: widget.localeController,
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.themeController, widget.localeController]),
          builder: (context, _) {
            final locale = widget.localeController.locale;
            Intl.defaultLocale = (locale ?? const Locale('ar')).languageCode;

            return MaterialApp(
              key: ValueKey(locale?.languageCode ?? 'ar'),
              debugShowCheckedModeBanner: false,
              onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: widget.themeController.themeMode,
              routes: {
                '/sync': (context) => const SyncCenterScreen(),
              },
              home: StartupShell(
                isInitialized: _isInitialized,
                child: const Scaffold(
                  backgroundColor: Colors.red,
                  body: Center(
                    child: Text(
                      'HASOOB TEST SCREEN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StartupShell extends StatelessWidget {
  final bool isInitialized;
  final Widget child;

  const StartupShell({
    super.key,
    required this.isInitialized,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        StartupDiagnostic.instance.stage,
        StartupDiagnostic.instance.error,
        StartupDiagnostic.instance.elapsedSeconds,
        StartupDiagnostic.instance.degradedSync,
      ]),
      builder: (context, _) {
        final error = StartupDiagnostic.instance.error.value;
        final stage = StartupDiagnostic.instance.stage.value;

        if (error != null) {
          return _StartupErrorUI(error: error);
        }

        if (isInitialized && stage == StartupStage.running) {
          return child;
        }

        return const _StartupLoadingUI();
      },
    );
  }
}

class _StartupLoadingUI extends StatelessWidget {
  const _StartupLoadingUI();

  @override
  Widget build(BuildContext context) {
    final diag = StartupDiagnostic.instance;
    final stage = diag.stage.value;
    final seconds = diag.elapsedSeconds.value;
    final degraded = diag.degradedSync.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2F80ED)),
            const SizedBox(height: 24),
            Text(
              stage.label,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Stage: ${stage.name} (${seconds}s)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            if (degraded) ...[
              const SizedBox(height: 8),
              const Text(
                'Degraded Sync Mode Active',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 48),
            const Text(
              'Startup diagnostics v3',
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  final String error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: _StartupErrorUI(error: error),
      ),
    );
  }
}

class _StartupErrorUI extends StatelessWidget {
  final String error;
  const _StartupErrorUI({required this.error});

  @override
  Widget build(BuildContext context) {
    final diag = StartupDiagnostic.instance;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Startup Failure',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Stage: ${diag.stage.value.name} | Elapsed: ${diag.elapsedSeconds.value}s',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontFamily: 'monospace'),
                    ),
                    if (diag.lastLog.value != null) ...[
                      const Divider(color: Colors.white10, height: 20),
                      Text(
                        'Last log: ${diag.lastLog.value}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Please refresh the page or try a different browser.\nIf on mobile, ensure your browser supports WebAssembly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 32),
              if (!kIsWeb)
                ElevatedButton(
                  onPressed: () => io.exit(1),
                  child: const Text('Close App'),
                ),
              if (kIsWeb)
                TextButton.icon(
                  onPressed: () => StartupDiagnostic.instance.lastTrace != null 
                    ? debugPrint(StartupDiagnostic.instance.lastTrace) 
                    : null,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Print Trace to Console'),
                ),
              const SizedBox(height: 24),
              const Text(
                'Startup diagnostics v3',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
