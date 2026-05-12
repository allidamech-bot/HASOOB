import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/business/business_context.dart';
import '../../core/app_theme.dart';
import '../../core/utils/web_utils.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firebase_bootstrap.dart';
import '../main_navigation_screen.dart';
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
  @override
  void initState() {
    super.initState();
    if (widget.firebaseEnabled && !_disableAnalyticsBootstrap) {
      try {
        FirebaseAnalytics.instance.logEvent(name: 'app_open_custom').catchError((Object error) {
          debugPrint('[Startup] AuthGate analytics ignored: $error');
        });
      } catch (error) {
        debugPrint('[Startup] AuthGate analytics ignored: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseEnabled) {
      return _DegradedNoAuthShell(bootstrapResult: widget.bootstrapResult);
    }

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LaunchSplashScreen();
        }

        if (snapshot.data != null) {
          final user = snapshot.data!;
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

        return const Stack(
          children: [
            AuthShell(),
            _CloudSyncPassiveBanner(
              message: 'Cloud sync is preparing...',
            ),
          ],
        );
      },
    );
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
      bottom: 16,
      start: 16,
      end: 16,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: (isError ? Colors.orange.shade900 : Colors.black).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isError ? Icons.sync_problem_rounded : Icons.sync_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
            message: 'Cloud sync unavailable. Your data is saved locally.',
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
                  if (result.errorType != null) Text('Error Type: ${result.errorType}'),
                  if (result.errorMessage != null)
                    Text('Error Msg: ${result.errorMessage}'),
                  if (result.configDiagnostics.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text('Config Presence:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...result.configDiagnostics.entries.map(
                      (e) => Text('  ${e.key}: ${e.value ? 'PRESENT' : 'MISSING'}'),
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

class _LaunchSplashScreen extends StatelessWidget {
  const _LaunchSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _SplashBackground(
        child: _SplashLogo(),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF133B78),
              Color(0xFF0E2C5C),
              AppTheme.background,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              top: -140,
              left: -120,
              child: _GlowCircle(
                size: 340,
                color: AppTheme.accentSoft,
                opacity: 0.10,
              ),
            ),
            const Positioned(
              right: -120,
              bottom: -150,
              child: _GlowCircle(
                size: 360,
                color: AppTheme.accent,
                opacity: 0.10,
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoBoxSize =
            (constraints.biggest.shortestSide * 0.58).clamp(220.0, 340.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Center(
              child: Container(
                width: logoBoxSize,
                height: logoBoxSize,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.white,
                        size: 112,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}
