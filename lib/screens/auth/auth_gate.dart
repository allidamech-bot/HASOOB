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
          return const PremiumSplashScreen();
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
      bottom: 24,
      start: 24,
      end: 24,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Dismissible(
              key: const Key('local-mode-banner'),
              child: Material(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isError ? AppTheme.accentCyan.withValues(alpha: 0.3) : AppTheme.border,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isError ? AppTheme.accentCyan : AppTheme.accentBlue).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isError ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                          color: isError ? AppTheme.accentCyan : AppTheme.accentBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isError ? 'الوضع المحلي مفعّل' : 'المزامنة مفعلة',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isError 
                                ? 'بياناتك محفوظة بأمان على هذا الجهاز.'
                                : 'بياناتك متزامنة مع السحابة.',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
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

// Removed old splash widgets as they are replaced by PremiumSplashScreen
