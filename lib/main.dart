// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:hasoob_app/core/app_locale_controller.dart';
import 'package:hasoob_app/core/app_theme.dart';
import 'package:hasoob_app/core/app_theme_controller.dart';
import 'package:hasoob_app/core/services/startup_coordinator.dart';
import 'package:hasoob_app/data/services/firebase_bootstrap.dart';
import 'package:hasoob_app/l10n/app_localizations.dart';
import 'package:hasoob_app/screens/auth/auth_gate.dart';
import 'package:hasoob_app/screens/sync_center_screen.dart';
import 'package:hasoob_app/core/utils/web_utils.dart';

const bool disableWebDatabaseBootstrap = bool.fromEnvironment('disableWebDatabaseBootstrap');

Future<void> main() async {
  // 1. Crash Containment: Set up global error handlers immediately
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[GlobalError] FlutterError: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[GlobalError] PlatformDispatcherError: $error');
    debugPrint(stack.toString());
    return true;
  };

  try {
    // 2. Minimal initialization before first render
    WidgetsFlutterBinding.ensureInitialized();

    // 3. Render-first: Start UI as soon as possible
    // We only load critical UI-blocking controllers here with tight timeouts
    final themeController = await AppThemeController.load().timeout(
      const Duration(seconds: 3),
      onTimeout: () => AppThemeController(),
    );
    final localeController = await AppLocaleController.load().timeout(
      const Duration(seconds: 3),
      onTimeout: () => AppLocaleController(),
    );

    // 4. Date formatting (usually fast, but guarded)
    await initializeDateFormatting().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );

    // 5. Desktop DB setup (fast)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 6. Fast-track Firebase initialization (guarded)
    FirebaseBootstrapResult firebaseResult;
    try {
      firebaseResult = await FirebaseBootstrap.initialize().timeout(const Duration(seconds: 5));
    } catch (e) {
      firebaseResult = FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase timeout during early bootstrap: $e',
        selectedPlatform: 'unknown',
        webConfigExists: false,
      );
    }

    runApp(
      HasoobApp(
        firebaseResult: firebaseResult,
        themeController: themeController,
        localeController: localeController,
      ),
    );
  } catch (e, st) {
    debugPrint('[Startup] Critical error during main bootstrap: $e');
    debugPrint(st.toString());
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class HasoobApp extends StatefulWidget {
  const HasoobApp({
    super.key,
    required this.firebaseResult,
    required this.themeController,
    required this.localeController,
  });

  final FirebaseBootstrapResult firebaseResult;
  final AppThemeController themeController;
  final AppLocaleController localeController;

  @override
  State<HasoobApp> createState() => _HasoobAppState();
}

class _HasoobAppState extends State<HasoobApp> {
  @override
  void initState() {
    super.initState();
    
    // 7. Post-frame initialization: Move heavy work after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finishInitialization();
    });
  }

  Future<void> _finishInitialization() async {
    // A. Remove splash immediately to show the app shell
    try {
      WebUtils.removeSplash();
    } catch (_) {}

    // B. Web Database (WASM) - Heavy initialization delayed
    if (kIsWeb && !disableWebDatabaseBootstrap) {
      try {
        databaseFactory = await Future.sync(() {
          return createDatabaseFactoryFfiWeb(
            options: SqfliteFfiWebOptions(
              sqlite3WasmUri: Uri.parse('sqlite3.wasm'),
              // ignore: invalid_use_of_visible_for_testing_member
              forceAsBasicWorker: defaultTargetPlatform == TargetPlatform.iOS, // Required for Safari/iOS WASM support
            ),
          );
        }).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[Startup] Web database failed to initialize: $e');
      }
    }

    // C. Startup Coordinator handles non-critical services (Sync, Connectivity, Auth listeners)
    await StartupCoordinator.instance.start(widget.firebaseResult);
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
              home: widget.firebaseResult.isConfigured
                  ? const AuthGate(firebaseEnabled: true)
                  : AuthGate(
                      firebaseEnabled: false,
                      bootstrapResult: widget.firebaseResult,
                    ),
            );
          },
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                Text(
                  error,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    if (kIsWeb) {
                      WebUtils.reloadPage();
                    } else {
                      // On mobile/desktop we might not be able to "reload" easily
                      // but we could try to re-run main if we restructured it.
                      // For now, just show instructions.
                    }
                  },
                  child: const Text('Retry'),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Try refreshing the page or using a different browser.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
