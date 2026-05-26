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
    final color = accentColor ?? AppTheme.accentBlue;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceSecondary : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.18) : AppTheme.lightBorder,
          width: 1.5,
        ),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.08),
                  AppTheme.surfaceSecondary,
                  AppTheme.surfaceSecondary.withValues(alpha: 0.9),
                ],
              )
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Top mini rail to ground the design
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3,
              child: Container(
                color: color.withValues(alpha: 0.7),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon Capsule
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? color.withValues(alpha: 0.15)
                          : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                      ),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trend Badge (Optional)
                  if (trendText != null && trendText!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTrendUp == true
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTrendUp == true ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10,
                            color: isTrendUp == true ? AppTheme.success : AppTheme.danger,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trendText!,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isTrendUp == true ? AppTheme.success : AppTheme.danger,
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
