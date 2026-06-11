import 'package:flutter/material.dart';
import '../core/app_copy.dart';
import '../core/app_theme.dart';
import '../core/app_formatters.dart';
import '../data/services/reports/report_models.dart';

class BusinessHealthModule extends StatefulWidget {
  final ReportsSnapshot snapshot;

  const BusinessHealthModule({
    super.key,
    required this.snapshot,
  });

  @override
  State<BusinessHealthModule> createState() => _BusinessHealthModuleState();
}

class _BusinessHealthModuleState extends State<BusinessHealthModule>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isAr = !copy.isEnglish;

    // Calculate health score dynamically
    int healthScore = 100;
    // Deduct for low stock (max 30% reduction)
    final lowStockCount = widget.snapshot.lowStockItems.length;
    healthScore -= (lowStockCount * 8).clamp(0, 30);

    // Deduct if trial balance is not balanced
    if (!widget.snapshot.trialBalanceSummary.isBalanced) {
      healthScore -= 15;
    }

    healthScore = healthScore.clamp(30, 100);

    // Determine status text & colors based on score
    final String statusText;
    final String subtitleText;
    final Color healthColor;
    final Color glowColor;

    if (healthScore >= 90) {
      statusText = isAr
          ? "ظƒظ„ ط§ظ„ط£ظ†ط¸ظ…ط© طھط¹ظ…ظ„ ط¨ظƒظپط§ط،ط©"
          : "All Systems Nominal";
      subtitleText =
          isAr ? "ط­ط§ظ„ط© ط§ظ„ط¹ظ…ظ„ ظ…ظ…طھط§ط²ط©" : "Excellent performance";
      healthColor = AppTheme.aiGreen;
      glowColor = AppTheme.aiGreen.withValues(alpha: 0.3);
    } else if (healthScore >= 75) {
      statusText =
          isAr ? "ط­ط§ظ„ط© ط§ظ„ط¹ظ…ظ„ ظ…ط³طھظ‚ط±ط©" : "Business State Stable";
      subtitleText = isAr
          ? "ط§ظ†طھط¨ط§ظ‡ ط¨ط³ظٹط· ظ…ط·ظ„ظˆط¨"
          : "Minor attention requested";
      healthColor = AppTheme.aiGold;
      glowColor = AppTheme.aiGold.withValues(alpha: 0.3);
    } else {
      statusText = isAr ? "ظٹط­طھط§ط¬ ط§ظ†طھط¨ط§ظ‡ظƒ" : "Needs Attention";
      subtitleText =
          isAr ? "ظ…ط·ظ„ظˆط¨ ط¥ط¬ط±ط§ط، ظپظˆط±ظٹ" : "Immediate action required";
      healthColor = AppTheme.aiRed;
      glowColor = AppTheme.aiRed.withValues(alpha: 0.3);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.commandGradient(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.isDark(context)
              ? AppTheme.aiBlue.withValues(alpha: 0.2)
              : AppTheme.borderFor(context),
          width: 1,
        ),
        boxShadow: AppTheme.isDark(context)
            ? [
                BoxShadow(
                  color: AppTheme.aiBlue.withValues(alpha: 0.07),
                  blurRadius: 24,
                  spreadRadius: 0,
                )
              ]
            : AppTheme.softShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.aiBlue.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -50,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.aiGold.withValues(alpha: 0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Left: Radial business health score with animated pulsing ring
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.isDark(context)
                            ? AppTheme.aiCard
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 16,
                            spreadRadius: 3,
                          ),
                        ],
                        border: Border.all(
                          color: healthColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$healthScore%",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: healthColor,
                                letterSpacing: 0,
                              ),
                            ),
                            Text(
                              isAr ? "ط§ظ„ط­ط§ظ„ط©" : "HEALTH",
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryFor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Center: Business status details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isAr
                              ? "ظ…ط±ظƒط² ظ‚ظٹط§ط¯ط© ط§ظ„ط£ط¹ظ…ط§ظ„"
                              : "AI Business Core",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.aiBlue,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusText,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical divider
                  Container(
                    height: 80,
                    width: 1,
                    color: AppTheme.borderFor(context),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  // Right: Stack of 3 mini KPIs
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMiniKpi(
                        context,
                        icon: Icons.trending_up,
                        iconColor: AppTheme.aiBlue,
                        label: isAr ? "ط§ظ„ظ…ط¨ظٹط¹ط§طھ" : "Sales",
                        value:
                            AppFormatters.currency(widget.snapshot.totalSales),
                      ),
                      const SizedBox(height: 8),
                      _buildMiniKpi(
                        context,
                        icon: Icons.warning_amber_rounded,
                        iconColor: lowStockCount > 0
                            ? AppTheme.aiRed
                            : AppTheme.aiGreen,
                        label: isAr ? "ظ†ظˆط§ظ‚طµ ط§ظ„ظ…ط®ط²ظˆظ†" : "Low Stock",
                        value: isAr
                            ? "$lowStockCount ظ…ظˆط§ط¯"
                            : "$lowStockCount items",
                      ),
                      const SizedBox(height: 8),
                      _buildMiniKpi(
                        context,
                        icon: Icons.sync,
                        iconColor: AppTheme.aiGreen,
                        label: isAr ? "ط§ظ„ظ…ط²ط§ظ…ظ†ط©" : "Sync",
                        value: isAr ? "ظ…ط³طھظ‚ط±ط©" : "Stable",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKpi(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondaryFor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
