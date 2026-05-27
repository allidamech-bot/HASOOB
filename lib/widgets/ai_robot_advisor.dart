import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class AiRobotAdvisor extends StatefulWidget {
  final String greeting;
  final String advisorTitle;
  final String? suggestion;
  final bool isCompact;

  const AiRobotAdvisor({
    super.key,
    required this.greeting,
    required this.advisorTitle,
    this.suggestion,
    this.isCompact = false,
  });

  @override
  State<AiRobotAdvisor> createState() => _AiRobotAdvisorState();
}

class _AiRobotAdvisorState extends State<AiRobotAdvisor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) return _buildCompact();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D1526),
                Color(0xFF0A1020),
                Color(0xFF060912),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.aiBlue.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.aiBlue.withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextContent(isDesktop: true),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildAnimatedRobot(size: 200),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildAnimatedRobot(size: 160),
                    const SizedBox(height: 32),
                    _buildTextContent(isDesktop: false),
                  ],
                ),
        );
      }
    );
  }

  Widget _buildTextContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.aiBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.aiBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.aiGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x9910B981),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.advisorTitle,
                style: const TextStyle(
                  color: AppTheme.aiBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.greeting,
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: AppTheme.aiTextPrimary,
            fontSize: isDesktop ? 36 : 28,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        if (widget.suggestion != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.suggestion!,
            textAlign: isDesktop ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              color: AppTheme.aiTextSecondary,
              fontSize: isDesktop ? 18 : 16,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.aiBlue,
            foregroundColor: AppTheme.aiDeep,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: AppTheme.aiBlue.withValues(alpha: 0.5),
          ),
          child: const Text(
            'عرض ملخص اليوم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedRobot({required double size}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Massive outer glow
              Container(
                width: size * 1.5,
                height: size * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiBlue.withValues(
                          alpha: 0.15 * _glowAnimation.value),
                      blurRadius: size * 0.8,
                      spreadRadius: size * 0.2,
                    ),
                  ],
                ),
              ),
              // Inner energy ring
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: size * 1.2,
                  height: size * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.aiBlue.withValues(alpha: 0.2),
                        AppTheme.aiBlue.withValues(alpha: 0.0),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.aiBlue.withValues(
                          alpha: 0.4 * _glowAnimation.value),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Robot Head
              _RobotFaceIcon(size: size),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompact() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.aiBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.aiBlue
                  .withValues(alpha: 0.3 * _glowAnimation.value),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RobotFaceIcon(size: 28),
              SizedBox(width: 12),
              Text(
                'المستشار نشط',
                style: TextStyle(
                  color: AppTheme.aiBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RobotFaceIcon extends StatelessWidget {
  final double size;
  const _RobotFaceIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RobotPainter(),
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dark sleek head
    final headPaint = Paint()
      ..color = const Color(0xFF0F182B)
      ..style = PaintingStyle.fill;
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.7),
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(headRect, headPaint);

    // Head border with neon glow
    final borderPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;
    canvas.drawRRect(headRect, borderPaint);
    
    // Visor background
    final visorPaint = Paint()
      ..color = const Color(0xFF050810)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.3, w * 0.6, h * 0.25),
        Radius.circular(w * 0.1),
      ),
      visorPaint,
    );

    // Eyes glow
    final eyeGlowPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset(w * 0.35, h * 0.42), w * 0.08, eyeGlowPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.42), w * 0.08, eyeGlowPaint);

    // Eyes
    final eyePaint = Paint()
      ..color = const Color(0xFF80E5FF)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.35, h * 0.42), w * 0.05, eyePaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.42), w * 0.05, eyePaint);

    // Antenna
    final antennaPaint = Paint()
      ..color = AppTheme.aiBlue
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.1),
      Offset(w * 0.5, 0),
      antennaPaint,
    );
    canvas.drawCircle(Offset(w * 0.5, 0), w * 0.04, Paint()..color = AppTheme.aiBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
