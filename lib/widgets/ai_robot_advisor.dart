import 'dart:math' as math;
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
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
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
        final isDesktop = constraints.maxWidth > 850;
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F1322),
                Color(0xFF090B13),
                Color(0xFF0C0E1B),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.aiGold.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.aiGold.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppTheme.aiBlue.withValues(alpha: 0.04),
                blurRadius: 60,
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Positioned(
                  right: -100,
                  top: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.aiGold.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: isDesktop ? 48 : 24),
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: _buildTextContent(isDesktop: true),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 3,
                              child: _buildAnimatedRobot(size: 260),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildAnimatedRobot(size: 120),
                            const SizedBox(height: 24),
                            _buildTextContent(isDesktop: false),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.commandGradient(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.aiGold.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _buildAnimatedRobot(size: 80),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.aiGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.advisorTitle.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.aiGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.greeting,
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (widget.suggestion != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.suggestion!,
                    style: const TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTextContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Premium status chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.aiGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.aiGold.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.aiGold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiGold.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.advisorTitle.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.aiGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        
        // Large title
        Text(
          widget.greeting,
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: AppTheme.aiTextPrimary,
            fontSize: isDesktop ? 36 : 22,
            fontWeight: FontWeight.w900,
            height: 1.3,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        
        // Subtitle suggestion
        if (widget.suggestion != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.suggestion!,
            textAlign: isDesktop ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              color: AppTheme.aiTextSecondary,
              fontSize: isDesktop ? 16 : 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        
        const SizedBox(height: 36),
        
        // Premium Golden CTA button
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.aiGoldGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.aiGold.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'عرض ملخص اليوم',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
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
        // Floating up and down
        final floatOffset = math.sin(_controller.value * 2 * math.pi) * 10;
        
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Aura Outer Gold Ring
                Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Container(
                    width: size * 0.95,
                    height: size * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.aiGold.withValues(alpha: 0.15),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                ),
                
                // 2. Rotating Aura Inner Blue Ring
                Transform.rotate(
                  angle: -_rotateAnimation.value * 1.5,
                  child: Container(
                    width: size * 0.82,
                    height: size * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.aiBlue.withValues(alpha: 0.2),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                ),
                
                // 3. Gold Energy Orbit Dot
                Transform.rotate(
                  angle: _rotateAnimation.value * 2,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppTheme.aiGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.aiGold,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 4. Large Soft Outer Glow Layer
                Container(
                  width: size * 0.75,
                  height: size * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.aiGold.withValues(alpha: 0.08 * _glowAnimation.value),
                        blurRadius: size * 0.4,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: AppTheme.aiBlue.withValues(alpha: 0.08),
                        blurRadius: size * 0.5,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                ),

                // 5. Sleek Robot Body / Base (Hologram pedestal)
                Positioned(
                  bottom: size * 0.05,
                  child: SizedBox(
                    width: size * 0.6,
                    height: size * 0.25,
                    child: CustomPaint(
                      painter: _PedestalPainter(),
                    ),
                  ),
                ),

                // 6. Glowing Energy Orb/Visor Center
                Transform.scale(
                  scale: 1.0 + (math.sin(_controller.value * 2 * math.pi) * 0.03),
                  child: Container(
                    width: size * 0.62,
                    height: size * 0.62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF141F3D),
                          const Color(0xFF0A0E1A).withValues(alpha: 0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.aiGold.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppTheme.aiBlue.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.aiGold.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating Matrix Core
                          Transform.rotate(
                            angle: _rotateAnimation.value * 0.2,
                            child: CustomPaint(
                              size: Size(size * 0.6, size * 0.6),
                              painter: _RobotCorePainter(controllerValue: _controller.value),
                            ),
                          ),
                          // Premium Visor Glass
                          _VisorWidget(size: size * 0.6),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VisorWidget extends StatelessWidget {
  final double size;
  const _VisorWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VisorPainter(),
      ),
    );
  }
}

class _VisorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glowing metallic visor background with radial reflection
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.3),
      Radius.circular(w * 0.08),
    );

    // Visor dark background (cyber tech deep black)
    final visorBg = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF0F1A30), Color(0xFF020408)],
        center: Alignment(0, -0.3),
      ).createShader(Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.3))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(visorRect, visorBg);

    // Multiple concentric glowing visor borders (Gold/Blue)
    final visorBorderGold = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(visorRect, visorBorderGold);

    final visorBorderBlue = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.37, w * 0.76, h * 0.26),
        Radius.circular(w * 0.06),
      ),
      visorBorderBlue,
    );

    // Dynamic grid pattern inside visor
    final gridPaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (double x = w * 0.15; x < w * 0.85; x += w * 0.05) {
      canvas.drawLine(Offset(x, h * 0.38), Offset(x, h * 0.62), gridPaint);
    }
    for (double y = h * 0.38; y < h * 0.62; y += h * 0.05) {
      canvas.drawLine(Offset(w * 0.15, y), Offset(w * 0.85, y), gridPaint);
    }

    // Visor reflection (top gradient light)
    final reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.15));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.11, h * 0.36, w * 0.78, h * 0.12),
        Radius.circular(w * 0.07),
      ),
      reflectionPaint,
    );

    // AI Glowing Digital Lenses/Eyes (Dual high-tech gold circles with circular cyan crosshairs)
    final eyeOuter = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final eyeInner = Paint()
      ..color = AppTheme.aiGold
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final eyeGlow = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Draw Left Eye
    final leftCenter = Offset(w * 0.35, h * 0.5);
    canvas.drawCircle(leftCenter, w * 0.08, eyeOuter);
    canvas.drawCircle(leftCenter, w * 0.04, eyeInner);
    canvas.drawCircle(leftCenter, w * 0.12, eyeGlow);

    // Left Eye crosshair ticks
    final tickPaint = Paint()
      ..color = AppTheme.aiBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(leftCenter.dx - w * 0.1, leftCenter.dy), Offset(leftCenter.dx - w * 0.06, leftCenter.dy), tickPaint);
    canvas.drawLine(Offset(leftCenter.dx + w * 0.06, leftCenter.dy), Offset(leftCenter.dx + w * 0.1, leftCenter.dy), tickPaint);
    canvas.drawLine(Offset(leftCenter.dx, leftCenter.dy - h * 0.1), Offset(leftCenter.dx, leftCenter.dy - h * 0.06), tickPaint);
    canvas.drawLine(Offset(leftCenter.dx, leftCenter.dy + h * 0.06), Offset(leftCenter.dx, leftCenter.dy + h * 0.1), tickPaint);

    // Draw Right Eye
    final rightCenter = Offset(w * 0.65, h * 0.5);
    canvas.drawCircle(rightCenter, w * 0.08, eyeOuter);
    canvas.drawCircle(rightCenter, w * 0.04, eyeInner);
    canvas.drawCircle(rightCenter, w * 0.12, eyeGlow);

    // Right Eye crosshair ticks
    canvas.drawLine(Offset(rightCenter.dx - w * 0.1, rightCenter.dy), Offset(rightCenter.dx - w * 0.06, rightCenter.dy), tickPaint);
    canvas.drawLine(Offset(rightCenter.dx + w * 0.06, rightCenter.dy), Offset(rightCenter.dx + w * 0.1, rightCenter.dy), tickPaint);
    canvas.drawLine(Offset(rightCenter.dx, rightCenter.dy - h * 0.1), Offset(rightCenter.dx, rightCenter.dy - h * 0.06), tickPaint);
    canvas.drawLine(Offset(rightCenter.dx, rightCenter.dy + h * 0.06), Offset(rightCenter.dx, rightCenter.dy + h * 0.1), tickPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RobotCorePainter extends CustomPainter {
  final double controllerValue;
  _RobotCorePainter({required this.controllerValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Glowing tech background lines
    final paint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, w * 0.42, paint);
    canvas.drawCircle(center, w * 0.32, paint);

    // High tech dashed circular arc
    final dashPaint = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw 8 HUD style segmented arcs around the circle
    final rect = Rect.fromCircle(center: center, radius: w * 0.36);
    for (double i = 0; i < 2 * math.pi; i += math.pi / 4) {
      canvas.drawArc(
        rect,
        i + (controllerValue * 2 * math.pi * 0.15),
        math.pi / 8,
        false,
        dashPaint,
      );
    }

    // Technology crosshair pointers
    final linePaint = Paint()
      ..color = AppTheme.aiBlue.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(Offset(w * 0.05, h / 2), Offset(w * 0.18, h / 2), linePaint);
    canvas.drawLine(Offset(w * 0.82, h / 2), Offset(w * 0.95, h / 2), linePaint);
    canvas.drawLine(Offset(w / 2, h * 0.05), Offset(w / 2, h * 0.18), linePaint);
    canvas.drawLine(Offset(w / 2, h * 0.82), Offset(w / 2, h * 0.95), linePaint);

    // Pulsing energy wave
    final waveRadius = w * 0.28 + (math.sin(controllerValue * 2 * math.pi) * w * 0.08);
    final wavePaint = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, waveRadius, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _RobotCorePainter oldDelegate) =>
      oldDelegate.controllerValue != controllerValue;
}

class _PedestalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw a futuristic metal pedestal curve at the bottom
    final path = Path()
      ..moveTo(w * 0.2, h)
      ..quadraticBezierTo(w * 0.3, h * 0.1, w * 0.5, h * 0.1)
      ..quadraticBezierTo(w * 0.7, h * 0.1, w * 0.8, h)
      ..lineTo(w * 0.7, h)
      ..quadraticBezierTo(w * 0.5, h * 0.4, w * 0.3, h)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.aiGold.withValues(alpha: 0.3),
          AppTheme.aiGold.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Laser neon accent line on pedestal top
    final borderPath = Path()
      ..moveTo(w * 0.3, h * 0.16)
      ..quadraticBezierTo(w * 0.5, h * 0.1, w * 0.7, h * 0.16);

    final borderPaint = Paint()
      ..color = AppTheme.aiGold.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

