import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';

class OrbitNodeCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? trendText;
  final bool? isTrendUp;

  const OrbitNodeCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor,
    this.trendText,
    this.isTrendUp,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.aiBlue;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.aiCard : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.2) : AppTheme.lightBorder,
          width: 1,
        ),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.07),
                  AppTheme.aiCard,
                  AppTheme.aiCard.withValues(alpha: 0.95),
                ],
              )
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppTheme.softShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Stack(
          children: [
            // Ambient subtle glow circle
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Top accent rail
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.8),
                      color.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Icon capsule
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: color, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.aiTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? AppTheme.aiTextPrimary
                                  : AppTheme.lightTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trend badge (optional)
                  if (trendText != null && trendText!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTrendUp == true
                            ? AppTheme.aiGreen.withValues(alpha: 0.12)
                            : AppTheme.aiRed.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTrendUp == true
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 9,
                            color: isTrendUp == true
                                ? AppTheme.aiGreen
                                : AppTheme.aiRed,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trendText!,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isTrendUp == true
                                  ? AppTheme.aiGreen
                                  : AppTheme.aiRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
