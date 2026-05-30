import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // Background Layer
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Color(0xFF0F172A), 
                    Color(0xFF070B14),
                  ],
                ),
              ),
            ),
          ),

          // Geometric Grid and Flow Lines
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flowController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _GeometricBackgroundPainter(
                    flowProgress: _flowController.value,
                  ),
                );
              },
            ),
          ),

          // Glowing Orbs
          _AnimatedGlowOrb(
            color: AppTheme.aiBlue.withValues(alpha: 0.08),
            size: 500,
            alignment: const Alignment(-0.8, -0.6),
            pulseController: _pulseController,
          ),
          _AnimatedGlowOrb(
            color: AppTheme.aiGold.withValues(alpha: 0.05),
            size: 600,
            alignment: const Alignment(0.8, 0.5),
            pulseController: _pulseController,
          ),

          // Main Content
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 800;
                        if (isDesktop) {
                          return _buildDesktopLayout();
                        }
                        return _buildMobileLayout();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return const Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Left Panel: System Signals
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SignalItem(title: 'حماية متقدمة', icon: Icons.security),
                      SizedBox(height: 20),
                      _SignalItem(title: 'مزامنة ذكية', icon: Icons.sync),
                      SizedBox(height: 20),
                      _SignalItem(title: 'تحليل مالي', icon: Icons.analytics),
                    ],
                  ),
                ),
              ),

              // Central Gate
              SizedBox(
                width: 400,
                child: Center(child: _BrandGate()),
              ),

              // Right Panel: Status Modules
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusModule(title: 'تهيئة البيانات', isActive: true),
                      SizedBox(height: 16),
                      _StatusModule(title: 'تحميل لوحة القيادة', isActive: false),
                      SizedBox(height: 16),
                      _StatusModule(title: 'فحص الاتصال الآمن', isActive: false),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom Rail
        Padding(
          padding: EdgeInsets.only(bottom: 40, left: 100, right: 100),
          child: _ProgressRail(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Spacer(),
        // Central Gate
        _BrandGate(),
        SizedBox(height: 50),
        
        // Compact Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Badge(title: 'حماية', icon: Icons.security),
            SizedBox(width: 12),
            _Badge(title: 'مزامنة', icon: Icons.sync),
            SizedBox(width: 12),
            _Badge(title: 'تحليل', icon: Icons.analytics),
          ],
        ),
        
        Spacer(),
        // Bottom Rail
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: _ProgressRail(),
        ),
      ],
    );
  }
}

class _AnimatedGlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final Alignment alignment;
  final AnimationController pulseController;

  const _AnimatedGlowOrb({
    required this.color,
    required this.size,
    required this.alignment,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final scale = 1.0 + (pulseController.value * 0.1);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color,
                    blurRadius: size / 2,
                    spreadRadius: size / 4,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GeometricBackgroundPainter extends CustomPainter {
  final double flowProgress;

  _GeometricBackgroundPainter({required this.flowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Cyan technical grid
    final gridPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 60.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += step) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // 2. Gold Light Paths Flowing
    final flowPaint = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawFlowLine(canvas, flowPaint, const Offset(0, 0), Offset(cx, cy), flowProgress);
    _drawFlowLine(canvas, flowPaint, Offset(size.width, 0), Offset(cx, cy), flowProgress);
    _drawFlowLine(canvas, flowPaint, Offset(0, size.height), Offset(cx, cy), flowProgress);
    _drawFlowLine(canvas, flowPaint, Offset(size.width, size.height), Offset(cx, cy), flowProgress);
  }

  void _drawFlowLine(Canvas canvas, Paint paint, Offset start, Offset end, double progress) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    
    // Create angular paths
    final midX = start.dx + (end.dx - start.dx) * 0.5;
    final midY = start.dy + (end.dy - start.dy) * 0.5;
    
    path.lineTo(midX, start.dy);
    path.lineTo(end.dx, midY);
    path.lineTo(end.dx, end.dy);

    final opacityModifier = 0.1 + (0.2 * math.max(0, math.sin((progress * math.pi * 2) - (start.dx + start.dy))));
    
    canvas.drawPath(path, paint..color = AppTheme.aiGold.withValues(alpha: opacityModifier));
  }

  @override
  bool shouldRepaint(covariant _GeometricBackgroundPainter oldDelegate) {
    return oldDelegate.flowProgress != flowProgress;
  }
}

class _BrandGate extends StatelessWidget {
  const _BrandGate();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glowing hex background
        Container(
          width: 280,
          height: 300,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppTheme.aiBlue.withValues(alpha: 0.15),
                blurRadius: 50,
                spreadRadius: 10,
              )
            ],
          ),
          child: ClipPath(
            clipper: _HexagonClipper(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.aiCard.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),

        // Hexagon Border via CustomPaint
        SizedBox(
          width: 280,
          height: 300,
          child: CustomPaint(
            painter: _HexagonBorderPainter(
              color: AppTheme.aiGold.withValues(alpha: 0.6),
              strokeWidth: 1.5,
            ),
          ),
        ),
        
        // Inner Content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance,
                size: 80,
                color: AppTheme.aiGold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'بوابة القيادة المالية الذكية',
              style: TextStyle(
                color: AppTheme.aiGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontFamily: AppTheme.fontFamilyArabic,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 2,
              decoration: BoxDecoration(
                color: AppTheme.aiBlue.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            )
          ],
        ),
      ],
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _getHexagonPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HexagonBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _HexagonBorderPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    canvas.drawPath(_getHexagonPath(size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Path _getHexagonPath(Size size) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  
  // Pointy top hexagon
  path.moveTo(w / 2, 0);
  path.lineTo(w, h * 0.25);
  path.lineTo(w, h * 0.75);
  path.lineTo(w / 2, h);
  path.lineTo(0, h * 0.75);
  path.lineTo(0, h * 0.25);
  path.close();
  
  return path;
}

class _SignalItem extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SignalItem({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _AngledPanelClipper(isRightSide: true),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 14, 24, 14),
          decoration: BoxDecoration(
            color: AppTheme.aiCard.withValues(alpha: 0.5),
            border: const Border(
              right: BorderSide(color: AppTheme.aiBlue, width: 3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamilyArabic,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 12),
              Icon(icon, color: AppTheme.aiBlue, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusModule extends StatelessWidget {
  final String title;
  final bool isActive;

  const _StatusModule({required this.title, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _AngledPanelClipper(isRightSide: false),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(24, 14, 30, 14),
          decoration: BoxDecoration(
            color: AppTheme.aiCard.withValues(alpha: isActive ? 0.7 : 0.4),
            border: Border(
              left: BorderSide(
                color: isActive ? AppTheme.aiGold : AppTheme.aiCardBorder,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? AppTheme.aiTextPrimary : AppTheme.aiTextSecondary,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontFamily: AppTheme.fontFamilyArabic,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 14),
              if (isActive)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.aiGold),
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.aiCardBorder,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AngledPanelClipper extends CustomClipper<Path> {
  final bool isRightSide;
  _AngledPanelClipper({required this.isRightSide});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final offset = h * 0.4;
    
    if (isRightSide) {
      // Slant on the left
      path.moveTo(offset, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
    } else {
      // Slant on the right
      path.moveTo(0, 0);
      path.lineTo(w - offset, 0);
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
    }
    
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Badge extends StatelessWidget {
  final String title;
  final IconData icon;

  const _Badge({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.aiCard.withValues(alpha: 0.6),
        border: Border.all(color: AppTheme.aiBlue.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.aiBlue, size: 14),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamilyArabic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRail extends StatefulWidget {
  const _ProgressRail();

  @override
  State<_ProgressRail> createState() => _ProgressRailState();
}

class _ProgressRailState extends State<_ProgressRail> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          children: List.generate(24, (index) {
            final delay = index / 24.0;
            final val = (_controller.value - delay) % 1.0;
            final opacity = val > 0 && val < 0.25 ? 1.0 : 0.15;
            
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppTheme.aiBlue.withValues(alpha: opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
