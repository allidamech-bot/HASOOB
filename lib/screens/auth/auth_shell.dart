import 'package:flutter/material.dart';
import '../../core/app_copy.dart';
import '../../core/app_theme.dart';
import '../../widgets/ai_robot_advisor.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthShell extends StatefulWidget {
  const AuthShell({super.key});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  bool _showLogin = true;

  List<String> _features(AppCopy copy) => copy.isEnglish
      ? [
          'Inventory & stock management',
          'AI-powered financial insights',
          'Invoicing & quotations',
          'Cloud sync & backup',
        ]
      : [
          'إدارة المخزون والأصناف',
          'رؤى مالية مدعومة بالذكاء الاصطناعي',
          'الفواتير وعروض الأسعار',
          'مزامنة سحابية واستعادة تلقائية',
        ];

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.aiHeroGradient),
        child: Stack(
          children: [
            // Atmospheric glow blobs
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiBlue.withValues(alpha: 0.06),
                      blurRadius: 200,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiGold.withValues(alpha: 0.04),
                      blurRadius: 150,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            // Content
            SafeArea(
              child: isWide
                  ? _buildWideLayout(copy)
                  : _buildNarrowLayout(copy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(AppCopy copy) {
    return Row(
      children: [
        // Left panel - branding
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.aiBlueGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.aiBlue.withValues(alpha: 0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.t('appTitle'),
                          style: const TextStyle(
                            color: AppTheme.aiTextPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'FINANCIAL AI SYSTEM',
                          style: TextStyle(
                            color: AppTheme.aiBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                AiRobotAdvisor(
                  greeting: copy.isEnglish
                      ? 'Your Financial AI Advisor'
                      : 'مستشارك المالي الذكي',
                  advisorTitle: copy.isEnglish
                      ? 'AI FINANCIAL ADVISOR'
                      : 'المستشار المالي الذكي',
                  suggestion: copy.isEnglish
                      ? 'I will help you make the best financial decisions for your business.'
                      : 'أنا هنا لمساعدتك على اتخاذ أفضل القرارات المالية لعملك.',
                ),
                const SizedBox(height: 40),
                // Feature bullets
                ..._features(copy).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.aiGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.aiGreen.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            f,
                            style: const TextStyle(
                              color: AppTheme.aiTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        // Right panel - forms
        Container(
          width: 460,
          decoration: const BoxDecoration(
            color: AppTheme.aiNavy,
            border: Border(
              left: BorderSide(color: AppTheme.aiCardBorder, width: 1),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: _formContent(copy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(AppCopy copy) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Compact header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.aiBlueGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.aiBlue.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.t('appTitle'),
                      style: const TextStyle(
                        color: AppTheme.aiTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'FINANCIAL AI SYSTEM',
                      style: TextStyle(
                        color: AppTheme.aiBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            AiRobotAdvisor(
              greeting: copy.isEnglish
                  ? 'Your Financial AI Advisor'
                  : 'مستشارك المالي الذكي',
              advisorTitle: copy.isEnglish
                  ? 'AI FINANCIAL ADVISOR'
                  : 'المستشار المالي الذكي',
              suggestion: copy.isEnglish
                  ? 'Making smarter financial decisions starts here.'
                  : 'القرارات المالية الأذكى تبدأ من هنا.',
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _formContent(copy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formContent(AppCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab switcher
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.aiCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.aiCardBorder),
          ),
          child: Row(
            children: [
              _tabButton(
                label: copy.t('loginTitle'),
                isActive: _showLogin,
                onTap: () => setState(() => _showLogin = true),
              ),
              _tabButton(
                label: copy.t('signUpTitle'),
                isActive: !_showLogin,
                onTap: () => setState(() => _showLogin = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showLogin
              ? LoginScreen(
                  key: ValueKey('login-${copy.isEnglish}'),
                  onOpenSignUp: () => setState(() => _showLogin = false),
                )
              : SignUpScreen(
                  key: ValueKey('signup-${copy.isEnglish}'),
                  onOpenLogin: () => setState(() => _showLogin = true),
                ),
        ),
      ],
    );
  }

  Widget _tabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.aiBlueGradient : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.aiBlue.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : AppTheme.aiTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
