import 'package:hasoob_app/data/services/database_initializer.dart';
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
// SQFlite imports will be handled by DatabaseInitializer, so they can be removed here
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:hasoob_app/core/app_locale_controller.dart';
import 'package:hasoob_app/core/app_theme.dart';
import 'package:hasoob_app/core/app_theme_controller.dart';
import 'package:hasoob_app/core/services/startup_coordinator.dart';
import 'package:hasoob_app/data/services/firebase_bootstrap.dart';
import 'package:hasoob_app/l10n/app_localizations.dart';
import 'package:hasoob_app/screens/auth/auth_gate.dart';
import 'package:hasoob_app/screens/sync_center_screen.dart';
import 'package:hasoob_app/core/utils/web_utils.dart';
import 'package:hasoob_app/widgets/premium_splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:hasoob_app/data/services/auth_service.dart';
import 'package:hasoob_app/data/repositories/product_repository.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';

// No longer needed here as initialization is moved
// const bool disableWebDatabaseBootstrap = bool.fromEnvironment('disableWebDatabaseBootstrap');

Future<void> main() async {
  // 1. Crash Containment: Set up global error handlers immediately
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('---------------------------------------------------------');
    debugPrint('[GlobalError] FlutterError detected:');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Library: ${details.library}');
    debugPrint('Stack trace:\n${details.stack}');
    debugPrint('---------------------------------------------------------');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('---------------------------------------------------------');
    debugPrint('[GlobalError] PlatformDispatcher error caught:');
    debugPrint('Error: $error');
    debugPrint('Stack trace:\n$stack');
    debugPrint('---------------------------------------------------------');
    // Returning true prevents the error from being reported to the console twice
    // but in some web environments we want it to propagate for browser devtools.
    return false; 
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

    // 5. Database Initialization is now handled by StartupCoordinator after first frame.

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
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: AuthService.instance),
          Provider<ProductRepository>(create: (_) => ProductRepository()),
          ChangeNotifierProvider<SyncManager>.value(value: SyncManager.instance),
        ],
        child: HasoobApp(
          firebaseResult: firebaseResult,
          themeController: themeController,
          localeController: localeController,
        ),
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
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    
    // 7. Post-frame initialization: Move heavy work after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[AppLifecycle] First frame rendered, deferred startup initiated.');
      _finishInitialization();
    });
  }

  Future<void> _finishInitialization() async {
    // A. Keep the Flutter-side splash visible for a moment to ensure smooth transition
    await Future.delayed(const Duration(milliseconds: 800));

    // B. Remove web splash
    try {
      WebUtils.removeSplash();
    } catch (_) {}

    // C. Startup Coordinator handles non-critical services (Sync, Connectivity, Auth listeners)
    await StartupCoordinator.instance.start(widget.firebaseResult);

    // D. Finalize initialization state with a slight delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isInitializing = false);
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
              home: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _isInitializing
                    ? const PremiumSplashScreen()
                    : (widget.firebaseResult.isConfigured
                        ? const AuthGate(firebaseEnabled: true)
                        : AuthGate(
                            firebaseEnabled: false,
                            bootstrapResult: widget.firebaseResult,
                          )),
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
        backgroundColor: const Color(0xFF070B14),
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
