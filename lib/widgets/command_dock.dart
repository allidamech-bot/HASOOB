import 'package:flutter/material.dart';
import '../core/app_copy.dart';
import '../core/app_theme.dart';

class CommandDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const CommandDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    // List of items in the bottom navigation dock
    final items = [
      _DockItemData(
        index: 0,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: copy.t('navDashboard'),
      ),
      _DockItemData(
        index: 1,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: copy.t('navInventory'),
      ),
      _DockItemData(
        index: 2,
        icon: Icons.add,
        selectedIcon: Icons.add,
        label: copy.t('navAdd'),
        isCenter: true,
      ),
      _DockItemData(
        index: 3,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: copy.t('navTransactions'),
      ),
      _DockItemData(
        index: 4,
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome,
        label: copy.t('navSmart'),
      ),
      _DockItemData(
        index: 5,
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
        label: copy.t('navReports'),
      ),
    ];

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.aiNavy.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: AppTheme.aiCardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.aiBlue.withValues(alpha: 0.05),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) {
            if (item.isCenter) {
              return _buildCenterButton(context, item);
            }
            return _buildNormalItem(context, item);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context, _DockItemData item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.aiBlueGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.aiBlue.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onDestinationSelected(item.index),
          child: Icon(
            item.icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildNormalItem(BuildContext context, _DockItemData item) {
    final isSelected = selectedIndex == item.index;
    const activeColor = AppTheme.aiBlue;
    const inactiveColor = AppTheme.aiTextMuted;

    return Expanded(
      child: Tooltip(
        message: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: () => onDestinationSelected(item.index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.aiBlue.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.aiBlue.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 9,
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

class _DockItemData {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isCenter;

  _DockItemData({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isCenter = false,
  });
}
