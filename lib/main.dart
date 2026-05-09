import 'dart:async';

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

Future<void> main() async {
  runApp(const _StartupLoadingScreen(message: 'Initializing...'));

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else if (kIsWeb) {
        databaseFactory = createDatabaseFactoryFfiWeb(
          options: SqfliteFfiWebOptions(
            sqlite3WasmUri: Uri.parse('sqlite3.wasm'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Database initialization warning: $e');
      // Continue anyway, app might show error UI later or use memory DB
    }

    await ConnectivityService.instance.initialize();
    final bootstrapResult = await FirebaseBootstrap.initialize();
    final themeController = await AppThemeController.load();
    final localeController = await AppLocaleController.load();

    if (bootstrapResult.isConfigured) {
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
        await FirebaseAnalytics.instance.logEvent(name: 'app_open_custom');
      } catch (e) {
        debugPrint('Firebase Analytics error: $e');
      }
    }

    runApp(
      HasoobApp(
        bootstrapResult: bootstrapResult,
        themeController: themeController,
        localeController: localeController,
      ),
    );

    unawaited(SyncManager.instance.initialize());
  } catch (e) {
    debugPrint('Critical startup error: $e');
    runApp(_StartupErrorScreen(error: e.toString()));
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  final String message;
  const _StartupLoadingScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2F80ED)),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Critical Startup Error',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Please refresh the page or restart the app.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
