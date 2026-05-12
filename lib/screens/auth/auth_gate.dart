import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/business/business_context.dart';
import '../../core/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../main_navigation_screen.dart';
import 'auth_shell.dart';

const bool _disableAnalyticsBootstrap =
    bool.fromEnvironment('disableAnalyticsBootstrap');

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.firebaseEnabled,
    this.degradedMessage,
  });

  final bool firebaseEnabled;
  final String? degradedMessage;

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
      return _DegradedNoAuthShell(message: widget.degradedMessage);
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

        return const AuthShell();
      },
    );
  }
}

class _DegradedNoAuthShell extends StatelessWidget {
  const _DegradedNoAuthShell({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final degradedMessage = message;
    try {
      BusinessContext.businessId;
    } catch (_) {
      BusinessContext.initialize(
        businessId: 'local-degraded',
        userId: 'local-degraded',
        role: 'owner',
      );
    }

    return Stack(
      children: [
        const MainNavigationScreen(),
        PositionedDirectional(
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
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Firebase unavailable - local degraded mode',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (degradedMessage != null && degradedMessage.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          degradedMessage,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
