import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_copy.dart';

class DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppTheme.aiNavy,
        border: Border(
          left: isRtl
              ? BorderSide.none
              : const BorderSide(color: AppTheme.aiCardBorder, width: 1.5),
          right: isRtl
              ? const BorderSide(color: AppTheme.aiCardBorder, width: 1.5)
              : BorderSide.none,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 14,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gold top accent line
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  AppTheme.aiGold,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Luxury Gold Logo Area
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.aiCard.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.aiCardBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppTheme.aiGoldGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.aiGold.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.t('brandName'),
                            style: TextStyle(
                              fontFamily: AppTheme.localeFontFamily(context),
                              color: AppTheme.aiGold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            copy.t('brandSubtitle'),
                            style: TextStyle(
                              color: AppTheme.aiTextSecondary
                                  .withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ), // end SafeArea logo

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              color: AppTheme.aiCardBorder.withValues(alpha: 0.5),
              thickness: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SidebarItem(
                  icon: Icons.psychology_rounded,
                  label: copy.t('aiAccountant'),
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.grid_view_rounded,
                  label: copy.t('navDashboard'),
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.inventory_2_rounded,
                  label: copy.t('navInventory'),
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.receipt_long_rounded,
                  label: copy.t('navTransactions'),
                  isSelected: selectedIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.auto_awesome_rounded,
                  label: copy.t('navSmart'),
                  isSelected: selectedIndex == 5,
                  onTap: () => onDestinationSelected(5),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.analytics_rounded,
                  label: copy.t('navReports'),
                  isSelected: selectedIndex == 6,
                  onTap: () => onDestinationSelected(6),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.settings_suggest_rounded,
                  label: copy.t('settings'),
                  isSelected: selectedIndex == 7,
                  onTap: () => onDestinationSelected(7),
                ),
              ],
            ),
          ),

          // Quick Add Floating CTA
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: InkWell(
              onTap: () => onDestinationSelected(3),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.aiGoldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiGold.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_rounded,
                        color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      copy.t('quickAdd'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.aiGold.withValues(alpha: 0.12),
                      AppTheme.aiGold.withValues(alpha: 0.03),
                    ],
                    begin: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                    end: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.aiGold.withValues(alpha: 0.34)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.aiGold.withValues(alpha: 0.05),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color:
                        isSelected ? AppTheme.aiGold : AppTheme.aiTextSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.aiGold
                            : AppTheme.aiTextSecondary,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Golden edge line for selected item
              if (isSelected)
                Positioned(
                  top: -4,
                  bottom: -4,
                  left: isRtl ? -16 : null,
                  right: isRtl ? null : -16,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: AppTheme.aiGoldGradient,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isRtl ? 4 : 0),
                        bottomLeft: Radius.circular(isRtl ? 4 : 0),
                        topRight: Radius.circular(isRtl ? 0 : 4),
                        bottomRight: Radius.circular(isRtl ? 0 : 4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
