import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? radius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final bool useGlass;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius,
    this.border,
    this.shadows,
    this.gradient,
    this.useGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    
    return Container(
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppTheme.surfaceSecondary : AppTheme.lightSurface),
        borderRadius: BorderRadius.circular(radius ?? AppTheme.radiusLarge),
        border: border ?? Border.all(
          color: isDark ? AppTheme.border : AppTheme.lightBorder,
          width: 1,
        ),
        gradient: gradient ?? (isDark ? AppTheme.premiumGradient : null),
        boxShadow: shadows ?? [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: -10,
            )
          else
            BoxShadow(
              color: AppTheme.accentBlue.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? AppTheme.radiusLarge),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

