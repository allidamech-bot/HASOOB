import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Glassmorphism card with optional glow border
class AiGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final Color? glowColor;
  final double? borderRadius;
  final VoidCallback? onTap;

  const AiGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.glowColor,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 16.0;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppTheme.aiCardBorder,
          width: 1,
        ),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
      ),
    );
  }
}

/// AI-styled page header
class AiPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;

  const AiPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiNavy,
        border: const Border(
          bottom: BorderSide(
            color: AppTheme.aiCardBorder,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gold accent line at top
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.aiGold,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 14),
            child: Row(
              children: [
                if (showBackButton) ...[
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppTheme.aiTextPrimary, size: 18),
                  ),
                  const SizedBox(width: 4),
                ],
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.aiTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppTheme.aiTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI metric card
class AiKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? trendText;
  final bool? isTrendUp;
  final VoidCallback? onTap;

  const AiKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.trendText,
    this.isTrendUp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AiGlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: accentColor.withValues(alpha: 0.2),
      glowColor: accentColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              if (trendText != null && isTrendUp != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isTrendUp! ? AppTheme.aiGreen : AppTheme.aiRed)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTrendUp!
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color:
                            isTrendUp! ? AppTheme.aiGreen : AppTheme.aiRed,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trendText!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isTrendUp!
                              ? AppTheme.aiGreen
                              : AppTheme.aiRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.aiTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alert card with severity
class AiAlertCard extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final AiAlertSeverity severity;
  final VoidCallback? onTap;

  const AiAlertCard({
    super.key,
    required this.message,
    this.subtitle,
    required this.icon,
    this.severity = AiAlertSeverity.warning,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      AiAlertSeverity.danger => AppTheme.aiRed,
      AiAlertSeverity.warning => AppTheme.aiGold,
      AiAlertSeverity.info => AppTheme.aiBlue,
      AiAlertSeverity.success => AppTheme.aiGreen,
    };

    return AiGlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.25),
      glowColor: color,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppTheme.aiTextMuted,
            ),
        ],
      ),
    );
  }
}

enum AiAlertSeverity { danger, warning, info, success }

/// Status chip
class AiStatusChip extends StatelessWidget {
  final String label;
  final AiAlertSeverity severity;

  const AiStatusChip({
    super.key,
    required this.label,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      AiAlertSeverity.danger => AppTheme.aiRed,
      AiAlertSeverity.warning => AppTheme.aiGold,
      AiAlertSeverity.info => AppTheme.aiBlue,
      AiAlertSeverity.success => AppTheme.aiGreen,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Empty state widget (compact premium variant)
class AiEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.sizeOf(context).width < 420;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12 : 18,
        vertical: isSmall ? 10 : 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.aiGold.withValues(alpha: 0.2)),
        color: AppTheme.aiGold.withValues(alpha: 0.05),
        boxShadow: [
          BoxShadow(
            color: AppTheme.aiGold.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 16),
            decoration: BoxDecoration(
              color: AppTheme.aiBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.aiBlue.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: isSmall ? 24 : 32,
              color: AppTheme.aiBlue.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: isSmall ? 14 : 16,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.aiTextSecondary,
                fontSize: isSmall ? 11 : 13,
                height: 1.35,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Loading state
class AiLoadingState extends StatelessWidget {
  final String? message;

  const AiLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.aiBlue),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                color: AppTheme.aiTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state
class AiErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AiErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.aiRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 36,
                  color: AppTheme.aiRed.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.aiTextSecondary, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AiActionButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                color: AppTheme.aiBlue,
                onTap: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header with accent
class AiSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppTheme.aiBlueGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppTheme.aiTextSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Primary action button with gradient
class AiActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isSmall;

  const AiActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.aiButtonDecoration(color: color),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 14 : 20,
              vertical: isSmall ? 10 : 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, color: Colors.white, size: isSmall ? 16 : 18),
                if ((isLoading || icon != null) && label.isNotEmpty)
                  SizedBox(width: isSmall ? 6 : 8),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall ? 13 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary/outlined button
class AiSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isSmall;

  const AiSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.aiCardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 14 : 20,
              vertical: isSmall ? 10 : 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      color: AppTheme.aiTextSecondary,
                      size: isSmall ? 16 : 18),
                  SizedBox(width: isSmall ? 6 : 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AI search field
class AiSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AiSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.aiCardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle:
              const TextStyle(color: AppTheme.aiTextMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.aiTextMuted, size: 20),
          suffixIcon: controller != null && (controller!.text.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.aiTextMuted, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// Data row for lists
class AiDataRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AiDataRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AiGlassCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Health score circular indicator
class AiHealthScore extends StatelessWidget {
  final double score;
  final double size;
  final String? label;

  const AiHealthScore({
    super.key,
    required this.score,
    this.size = 80,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppTheme.aiGreen
        : score >= 60
            ? AppTheme.aiGold
            : AppTheme.aiRed;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toInt()}',
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    color: AppTheme.aiTextMuted,
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Icon container for lists and cards
class AiIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AiIconContainer({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );
  }
}

// ─────────────────────────────────────────────
// MOBILE DESIGN SYSTEM
// ─────────────────────────────────────────────
class AiMobileConfig {
  static const double horizontalPadding = 16.0;
  static const double sectionGap = 16.0;
  static const double cardPadding = 16.0;
  static const double cardRadius = 20.0;
  static const double bottomClearance = 100.0;

  static const TextStyle pageTitle = TextStyle(color: AppTheme.aiTextPrimary, fontSize: 24, fontWeight: FontWeight.w800);
  static const TextStyle sectionTitle = TextStyle(color: AppTheme.aiTextPrimary, fontSize: 20, fontWeight: FontWeight.w700);
  static const TextStyle cardTitle = TextStyle(color: AppTheme.aiTextPrimary, fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle body = TextStyle(color: AppTheme.aiTextSecondary, fontSize: 13, fontWeight: FontWeight.w500);
  static const TextStyle caption = TextStyle(color: AppTheme.aiTextMuted, fontSize: 12, fontWeight: FontWeight.w500);
}

class AiMobilePageShell extends StatelessWidget {
  final Widget child;
  const AiMobilePageShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AiMobileConfig.bottomClearance),
        child: child,
      ),
    );
  }
}

class AiMobileSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const AiMobileSectionHeader({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AiMobileConfig.sectionTitle),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AiMobileKpiStrip extends StatelessWidget {
  final List<Widget> children;
  const AiMobileKpiStrip({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
      child: Row(children: children),
    );
  }
}

class AiMobileKpiChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const AiMobileKpiChip({super.key, required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: AiMobileConfig.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.aiTextPrimary)),
        ],
      ),
    );
  }
}

class AiMobileActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const AiMobileActionCard({super.key, required this.title, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return AiGlassCard(
      borderRadius: AiMobileConfig.cardRadius,
      padding: const EdgeInsets.all(AiMobileConfig.cardPadding),
      borderColor: color.withValues(alpha: 0.3),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(title, style: AiMobileConfig.cardTitle.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class AiMobileEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  const AiMobileEmptyState({super.key, required this.title, required this.subtitle, required this.icon, required this.actionLabel, required this.onAction});
  @override
  Widget build(BuildContext context) {
    return AiGlassCard(
      borderRadius: AiMobileConfig.cardRadius,
      padding: const EdgeInsets.all(AiMobileConfig.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.aiGold, size: 48),
          const SizedBox(height: 16),
          Text(title, style: AiMobileConfig.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: AiMobileConfig.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.aiGold, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }
}

class AiMobileFilterPanel extends StatelessWidget {
  final Widget child;
  const AiMobileFilterPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
      child: AiGlassCard(
        borderRadius: AiMobileConfig.cardRadius,
        padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.cardPadding, vertical: 12),
        child: child,
      ),
    );
  }
}
