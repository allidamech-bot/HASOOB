import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/ui/ui_tokens.dart';

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
    final cardRadius = radius ?? UITokens.radiusXl;

    return Container(
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppTheme.aiCard : AppTheme.lightSurface),
        borderRadius: BorderRadius.circular(cardRadius),
        border: border ?? Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.lightBorder,
          width: UITokens.borderWidthThin,
        ),
        gradient: gradient,
        boxShadow: shadows ?? [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: UITokens.blurStrong,
              offset: const Offset(0, UITokens.spaceXs),
            )
          else
            BoxShadow(
              color: AppTheme.accentBlue.withValues(alpha: 0.04),
              blurRadius: UITokens.blurMedium,
              offset: const Offset(0, UITokens.spaceXs),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

