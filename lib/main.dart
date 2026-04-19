import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/app_locale_controller.dart';
import 'core/app_theme.dart';
import 'core/app_theme_controller.dart';
import 'data/services/auth_service.dart';
import 'data/services/firebase_bootstrap.dart';
import 'data/services/sync_manager.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/auth/firebase_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final bootstrapResult = await FirebaseBootstrap.initialize();
  final themeController = await AppThemeController.load();
  final localeController = await AppLocaleController.load();

  if (bootstrapResult.isConfigured) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await FirebaseAnalytics.instance.logEvent(name: 'app_open_custom');
  }

  runApp(
    HasoobApp(
      bootstrapResult: bootstrapResult,
      themeController: themeController,
      localeController: localeController,
    ),
  );

  unawaited(SyncManager.instance.initialize());
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = AuthService.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(SyncManager.instance.onAuthenticated());
      } else {
        unawaited(SyncManager.instance.stopRealtimeSync());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SyncManager.instance.onAppResumed());
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
