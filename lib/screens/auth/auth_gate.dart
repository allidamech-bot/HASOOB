import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/business/business_context.dart';
import '../../core/app_theme.dart';
import '../../core/utils/web_utils.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firebase_bootstrap.dart';
import '../main_navigation_screen.dart';
import '../../widgets/premium_splash_screen.dart';
import 'auth_shell.dart';

const bool _disableAnalyticsBootstrap =
    bool.fromEnvironment('disableAnalyticsBootstrap');

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.firebaseEnabled,
    this.bootstrapResult,
  });

  final bool firebaseEnabled;
  final FirebaseBootstrapResult? bootstrapResult;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Timer? _authLoadingTimer;
  bool _authLoadingTimedOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.firebaseEnabled) {
      _authLoadingTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        debugPrint(
          '[AuthGate] Auth stream still waiting after 10s; '
          'showing non-destructive fallback.',
        );
        setState(() => _authLoadingTimedOut = true);
      });
    }
    if (widget.firebaseEnabled && !_disableAnalyticsBootstrap) {
      try {
        FirebaseAnalytics.instance
            .logEvent(name: 'app_open_custom')
            .catchError((Object error) {
          debugPrint('[Startup] AuthGate analytics ignored: $error');
        });
      } catch (error) {
        debugPrint('[Startup] AuthGate analytics ignored: $error');
      }
    }
  }

  @override
  void dispose() {
    _authLoadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseEnabled) {
      return _DegradedNoAuthShell(bootstrapResult: widget.bootstrapResult);
    }

    return StreamBuilder<User?>(
      initialData: AuthService.instance.currentUser,
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        final currentUser = snapshot.data ?? AuthService.instance.currentUser;

        if (snapshot.hasError) {
          debugPrint('[AuthGate] Auth stream error: ${snapshot.error}');
          if (currentUser != null) {
            return _authenticatedShell(currentUser);
          }
          return const Stack(
            children: [
              AuthShell(),
              _CloudSyncPassiveBanner(
                message: 'Local Mode Active',
                isError: true,
              ),
            ],
          );
        }

        if (currentUser != null) {
          _authLoadingTimer?.cancel();
          return _authenticatedShell(currentUser);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !_authLoadingTimedOut) {
          return const PremiumSplashScreen();
        }

        if (_authLoadingTimedOut &&
            snapshot.connectionState == ConnectionState.waiting) {
          debugPrint(
            '[AuthGate] Auth stream timeout fallback reached with no current user.',
          );
        }

        return const Stack(
          children: [
            AuthShell(),
            _CloudSyncPassiveBanner(
              message: 'Sign in to enable cloud sync.',
            ),
          ],
        );
      },
    );
  }

  Widget _authenticatedShell(User user) {
    var isBusinessReady = true;
    try {
      BusinessContext.businessId;
    } catch (_) {
      isBusinessReady = false;
    }
    if (!isBusinessReady) {
      BusinessContext.initialize(
        businessId: user.uid,
        userId: user.uid,
        role: 'owner',
      );
    }
    return const MainNavigationScreen();
  }
}

class _CloudSyncPassiveBanner extends StatelessWidget {
  const _CloudSyncPassiveBanner({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      bottom: 125, // Higher to clear bottom nav and Safari toolbar
      start: 16,
      end: 16,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Dismissible(
              key: const Key('local-mode-banner-top'),
              child: Material(
                color: AppTheme.surfaceSecondary.withValues(alpha: 0.98),
                elevation: 4,
                shadowColor: Colors.black26,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isError
                        ? AppTheme.accentCyan.withValues(alpha: 0.4)
                        : AppTheme.border,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_done_rounded,
                        color:
                            isError ? AppTheme.accentCyan : AppTheme.accentBlue,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.close_rounded,
                          size: 12, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DegradedNoAuthShell extends StatelessWidget {
  const _DegradedNoAuthShell({required this.bootstrapResult});

  final FirebaseBootstrapResult? bootstrapResult;

  @override
  Widget build(BuildContext context) {
    try {
      BusinessContext.businessId;
    } catch (_) {
      BusinessContext.initialize(
        businessId: 'local-degraded',
        userId: 'local-degraded',
        role: 'owner',
      );
    }

    final isDebug = WebUtils.isStartupDebugEnabled();

    return Stack(
      children: [
        const MainNavigationScreen(),
        if (isDebug && bootstrapResult != null)
          _TechnicalDiagnosticsOverlay(result: bootstrapResult!)
        else
          const _CloudSyncPassiveBanner(
            message: 'Local Mode Active',
            isError: true,
          ),
      ],
    );
  }
}

class _TechnicalDiagnosticsOverlay extends StatelessWidget {
  const _TechnicalDiagnosticsOverlay({required this.result});

  final FirebaseBootstrapResult result;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 12,
      start: 12,
      end: 12,
      child: SafeArea(
        child: Material(
          color: Colors.orange.shade900.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.3,
                fontFamily: 'monospace',
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DEBUG: Firebase Degraded Mode',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text('Platform: ${result.selectedPlatform}'),
                  Text('Web Config Exists: ${result.webConfigExists}'),
                  if (result.missingFields.isNotEmpty)
                    Text('Missing Fields: ${result.missingFields.join(', ')}'),
                  if (result.errorType != null)
                    Text('Error Type: ${result.errorType}'),
                  if (result.errorMessage != null)
                    Text('Error Msg: ${result.errorMessage}'),
                  if (result.configDiagnostics.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text('Config Presence:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...result.configDiagnostics.entries.map(
                      (e) => Text(
                          '  ${e.key}: ${e.value ? 'PRESENT' : 'MISSING'}'),
                    ),
                  ],
                  if (result.stackTrace != null) ...[
                    const SizedBox(height: 6),
                    const Text('Stack Trace (truncated):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      result.stackTrace!,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Removed old splash widgets as they are replaced by PremiumSplashScreen
