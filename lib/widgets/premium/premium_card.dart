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

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius,
    this.border,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppTheme.surface : AppTheme.lightSurface),
        borderRadius: BorderRadius.circular(radius ?? AppTheme.radiusLarge),
        border: border ?? Border.all(
          color: isDark 
            ? AppTheme.outlineDark.withValues(alpha: 0.5) 
            : AppTheme.outlineLight.withValues(alpha: 0.5),
          width: 1,
        ),
        gradient: gradient,
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
