import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// The AI Financial Advisor hero widget
/// Displays the robot AI advisor with animated glow and status
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildFull() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1526),
            Color(0xFF0A1020),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.aiBlue.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.aiBlue.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Robot avatar section
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.aiBlue.withValues(
                                alpha: 0.15 * _glowAnimation.value),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    // Inner ring
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.aiBlue.withValues(alpha: 0.15),
                            AppTheme.aiBlue.withValues(alpha: 0.03),
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.aiBlue.withValues(
                              alpha: 0.4 * _glowAnimation.value),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Robot face
                    const _RobotFaceIcon(size: 52),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          // Text section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.aiGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x9910B981),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.advisorTitle,
                      style: const TextStyle(
                        color: AppTheme.aiBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.greeting,
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.suggestion != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.suggestion!,
                    style: const TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.aiBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.aiBlue
                  .withValues(alpha: 0.2 * _glowAnimation.value),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RobotFaceIcon(size: 24),
              SizedBox(width: 8),
              Text(
                'AI',
                style: TextStyle(
                  color: AppTheme.aiBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// SVG-free robot face icon using custom paint
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

    // Head
    final headPaint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.6),
        Radius.circular(w * 0.12),
      ),
      headPaint,
    );

    // Head border
    final borderPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.6),
        Radius.circular(w * 0.12),
      ),
      borderPaint,
    );

    // Eyes glow
    final eyeGlowPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Left eye glow
    canvas.drawCircle(Offset(w * 0.32, h * 0.38), w * 0.1, eyeGlowPaint);
    // Right eye glow
    canvas.drawCircle(Offset(w * 0.68, h * 0.38), w * 0.1, eyeGlowPaint);

    // Eyes
    final eyePaint = Paint()
      ..color = AppTheme.aiBlue
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawCircle(Offset(w * 0.32, h * 0.38), w * 0.07, eyePaint);
    // Right eye
    canvas.drawCircle(Offset(w * 0.68, h * 0.38), w * 0.07, eyePaint);

    // Inner eye dots
    final innerEyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.33, h * 0.365), w * 0.025, innerEyePaint);
    canvas.drawCircle(Offset(w * 0.69, h * 0.365), w * 0.025, innerEyePaint);

    // Mouth - small horizontal line
    final mouthPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.7)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.32, h * 0.58),
      Offset(w * 0.68, h * 0.58),
      mouthPaint,
    );

    // Antenna
    final antennaPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.6)
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.15),
      Offset(w * 0.5, h * 0.05),
      antennaPaint,
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.04), w * 0.05,
        Paint()..color = AppTheme.aiBlue);

    // Neck/body connection
    final neckPaint = Paint()..color = const Color(0xFF1E3A5F);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.75, w * 0.24, h * 0.12),
      neckPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, h * 0.87, w * 0.6, h * 0.08),
      neckPaint,
    );

    // Border on neck
    final neckBorderPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.75, w * 0.24, h * 0.12),
      neckBorderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
