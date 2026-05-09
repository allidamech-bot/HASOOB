import 'dart:async';
import 'dart:ui';

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
import 'screens/auth/auth_gate.dart';
import 'screens/auth/firebase_setup_screen.dart';
import 'screens/sync_center_screen.dart';
import 'core/services/connectivity_service.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:io' as io;

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
  Timer? _timer;
  String? lastTrace;

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds.value = timer.tick;
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  void logStage(StartupStage newStage) {
    debugPrint('[Startup] [${elapsedSeconds.value}s] === STAGE: ${newStage.name} ===');
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

  runApp(const _StartupDiagnosticApp());

  try {
    StartupDiagnostic.instance.logStage(StartupStage.bindingInit);
    WidgetsFlutterBinding.ensureInitialized();

    StartupDiagnostic.instance.logStage(StartupStage.dateInit);
    await initializeDateFormatting().timeout(const Duration(seconds: 5));

    debugPrint('[Startup] Platform: kIsWeb=$kIsWeb');

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        StartupDiagnostic.instance.logStage(StartupStage.databaseInit);
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else if (kIsWeb) {
        StartupDiagnostic.instance.logStage(StartupStage.sqfliteWebInit);
        // Timeout added for Web WASM init
        databaseFactory = await Future.sync(() {
          return createDatabaseFactoryFfiWeb(
            options: SqfliteFfiWebOptions(
              sqlite3WasmUri: Uri.parse('sqlite3.wasm'),
            ),
          );
        }).timeout(const Duration(seconds: 10), onTimeout: () {
          throw TimeoutException('SQLite WASM initialization timed out after 10s');
        });
        debugPrint('[Startup] Web Database Factory set.');
      }
    } catch (e, st) {
      StartupDiagnostic.instance.fail('DB Factory Init: $e', st);
      return;
    }

    StartupDiagnostic.instance.logStage(StartupStage.connectivityInit);
    try {
      await ConnectivityService.instance.initialize().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Non-critical Connectivity error: $e');
    }

    StartupDiagnostic.instance.logStage(StartupStage.firebaseInit);
    final bootstrapResult = await FirebaseBootstrap.initialize().timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('Firebase initialization timed out after 10s');
    });

    StartupDiagnostic.instance.logStage(StartupStage.controllersInit);
    final results = await Future.wait([
      AppThemeController.load(),
      AppLocaleController.load(),
    ]).timeout(const Duration(seconds: 5));
    
    final themeController = results[0] as AppThemeController;
    final localeController = results[1] as AppLocaleController;

    if (bootstrapResult.isConfigured) {
      StartupDiagnostic.instance.logStage(StartupStage.analyticsInit);
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true).timeout(const Duration(seconds: 3));
        await FirebaseAnalytics.instance.logEvent(name: 'app_open_custom').timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Non-critical Analytics error: $e');
      }
    }

    StartupDiagnostic.instance.logStage(StartupStage.syncInit);
    // SyncManager initialization shouldn't block the main UI if possible, 
    // but we await it here as per existing logic.
    await SyncManager.instance.initialize().timeout(const Duration(seconds: 5));

    StartupDiagnostic.instance.logStage(StartupStage.running);
    StartupDiagnostic.instance.stopTimer();

    runApp(
      HasoobApp(
        bootstrapResult: bootstrapResult,
        themeController: themeController,
        localeController: localeController,
      ),
    );
  } catch (e, st) {
    StartupDiagnostic.instance.fail(e, st);
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
  late final SmartSyncTriggerService _smartSyncTriggerService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SmartSyncTriggerService.init(SyncManager.instance);
    _smartSyncTriggerService = SmartSyncTriggerService.instance;
    _smartSyncTriggerService.initialize();
    unawaited(_smartSyncTriggerService.onAppStarted());

    _authSubscription = AuthService.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(SyncManager.instance.onAuthenticated());
        unawaited(_smartSyncTriggerService.onAppStarted());
      } else {
        unawaited(SyncManager.instance.stopRealtimeSync());
      }
    });
  }

  @override
  void dispose() {
    _smartSyncTriggerService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SyncManager.instance.onAppResumed());
      unawaited(_smartSyncTriggerService.onAppStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeControllerScope(
      controller: widget.themeController,
      child: AppLocaleControllerScope(
        controller: widget.localeController,
        child: AnimatedBuilder(
          animation: widget.themeController,
          builder: (context, _) {
            return AnimatedBuilder(
              animation: widget.localeController,
              builder: (context, __) {
                final locale = widget.localeController.locale;
                Intl.defaultLocale = (locale ?? const Locale('ar')).languageCode;

                return MaterialApp(
                  key: ValueKey(locale?.languageCode ?? 'ar'),
                  debugShowCheckedModeBanner: false,
                  onGenerateTitle: (context) =>
                      AppLocalizations.of(context)!.appTitle,
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
                  home: widget.bootstrapResult.isConfigured
                      ? const AuthGate()
                      : FirebaseSetupScreen(
                          message: widget.bootstrapResult.message,
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StartupDiagnosticApp extends StatelessWidget {
  const _StartupDiagnosticApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: Center(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              StartupDiagnostic.instance.stage,
              StartupDiagnostic.instance.error,
              StartupDiagnostic.instance.elapsedSeconds,
            ]),
            builder: (context, _) {
              final error = StartupDiagnostic.instance.error.value;
              final stage = StartupDiagnostic.instance.stage.value;
              final seconds = StartupDiagnostic.instance.elapsedSeconds.value;

              if (error != null) {
                return _StartupErrorUI(error: error);
              }

              return Column(
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
                  const SizedBox(height: 48),
                  const Text(
                    'Startup diagnostics v1',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StartupErrorUI extends StatelessWidget {
  final String error;
  const _StartupErrorUI({required this.error});

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontFamily: 'monospace'),
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
                'Startup diagnostics v1',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
