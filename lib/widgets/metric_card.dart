import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor,
    this.caption,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.accent;
    final hasCaption = caption != null && caption!.trim().isNotEmpty;
    final isDark = AppTheme.isDark(context);
    final baseSurface = AppTheme.surfaceFor(context);
    final altSurface = AppTheme.surfaceAltFor(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            altSurface,
            baseSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 168;
          final veryTightHeight = constraints.maxHeight < 148;
          final cardPadding = veryTightHeight
              ? 12.0
              : compactHeight
                  ? 14.0
                  : 16.0;
          final iconSize = veryTightHeight
              ? 38.0
              : compactHeight
                  ? 40.0
                  : 44.0;
          final iconRadius = veryTightHeight
              ? 12.0
              : compactHeight
                  ? 13.0
                  : 14.0;
          final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryFor(context),
                fontWeight: FontWeight.w600,
                fontSize: veryTightHeight
                    ? 11
                    : compactHeight
                        ? 12
                        : null,
              );
          final valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: compactHeight ? -0.2 : -0.4,
                fontSize: veryTightHeight
                    ? 22
                    : compactHeight
                        ? 24
                        : null,
              );
          final captionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryFor(context),
                fontWeight: FontWeight.w600,
                fontSize: veryTightHeight
                    ? 10
                    : compactHeight
                        ? 11
                        : null,
              );

          return Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(iconRadius),
                        border: Border.all(color: color.withValues(alpha: 0.22)),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: compactHeight ? 20 : 22,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: veryTightHeight ? 8 : 10,
                      height: veryTightHeight ? 8 : 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: compactHeight ? 8 : 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compactHeight ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      SizedBox(height: compactHeight ? 5 : 8),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              value,
                              maxLines: 1,
                              softWrap: false,
                              style: valueStyle?.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.lightTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasCaption) ...[
                        SizedBox(height: compactHeight ? 4 : 6),
                        Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: captionStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
