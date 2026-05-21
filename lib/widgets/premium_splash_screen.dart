import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );




    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14), // Deepest navy
      body: Stack(
        children: [
          // 1. Base Layer: Deep Radial Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Color(0xFF0F172A), // Lighter navy
                    Color(0xFF070B14), // Deep navy
                  ],
                ),
              ),
            ),
          ),

          // 2. Mid Layer: Animated Glows (Blobs) for depth
          _AnimatedGlowBlob(
            color: AppTheme.accentBlue.withValues(alpha: 0.08),
            size: 400,
            offset: const Offset(-100, -100),
            duration: const Duration(seconds: 8),
          ),
          _AnimatedGlowBlob(
            color: AppTheme.accentGold.withValues(alpha: 0.05),
            size: 500,
            offset: const Offset(100, 200),
            duration: const Duration(seconds: 12),
            reverse: true,
          ),

          // 3. Pattern Layer: Subtle Finance/Business Grid
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
          ),

          // 4. Central Content: Floating Logo & Loader
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Combine entry scale/fade with a subtle continuous float
                // Entry fade/scale is handled by _fadeAnimation and _scaleAnimation.
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(

                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Floating Logo - No boundaries
                        _FloatingLogo(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Luxury Minimal Loader
                        const _PremiumLoader(),

                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 5. Signature Accent
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.4,
                child: Text(
                  'HASOOB ERP SYSTEM',
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedGlowBlob extends StatefulWidget {
  final Color color;
  final double size;
  final Offset offset;
  final Duration duration;
  final bool reverse;

  const _AnimatedGlowBlob({
    required this.color,
    required this.size,
    required this.offset,
    required this.duration,
    this.reverse = false,
  });

  @override
  State<_AnimatedGlowBlob> createState() => _AnimatedGlowBlobState();
}

class _AnimatedGlowBlobState extends State<_AnimatedGlowBlob> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<Offset>(
      begin: widget.offset,
      end: Offset(widget.offset.dx + 50, widget.offset.dy + 50),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.reverse) {
      _controller.repeat(reverse: true);
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: _animation.value.dx,
          top: _animation.value.dy,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color,
                  blurRadius: widget.size / 2,
                  spreadRadius: widget.size / 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FloatingLogo extends StatefulWidget {
  final Widget child;
  const _FloatingLogo({required this.child});

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}

class _PremiumLoader extends StatelessWidget {
  const _PremiumLoader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          CircularProgressIndicator(
            strokeWidth: 1,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold.withValues(alpha: 0.1)),
          ),
          const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
