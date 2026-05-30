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
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: AppTheme.aiGold.withValues(alpha: 0.02),
            blurRadius: 30,
            spreadRadius: 2,
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
                color: AppTheme.aiGold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.aiGold.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.aiGold.withValues(alpha: 0.05),
                    blurRadius: 15,
                    spreadRadius: -5,
                  ),
                ],
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
                          color: AppTheme.aiGold.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
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
                          copy.isEnglish ? 'HASOOB' : 'حاسوب',
                          style: const TextStyle(
                            color: AppTheme.aiGold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          copy.isEnglish
                              ? 'AI Financial OS'
                              : 'نظام الذكاء المالي',
                          style: TextStyle(
                            color: AppTheme.aiTextSecondary.withValues(alpha: 0.7),
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
          ),  // end SafeArea logo

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
                  icon: Icons.grid_view_rounded,
                  label: 'الرئيسية',
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.psychology_rounded,
                  label: 'المستشار المالي',
                  isSelected: selectedIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.people_alt_rounded,
                  label: 'العملاء والفواتير',
                  isSelected: selectedIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'المخزون والمشتريات',
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.analytics_rounded,
                  label: 'التقارير الذكية',
                  isSelected: selectedIndex == 5,
                  onTap: () => onDestinationSelected(5),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.settings_suggest_rounded,
                  label: 'الإعدادات',
                  isSelected: selectedIndex == 6,
                  onTap: () => onDestinationSelected(6),
                ),
              ],
            ),
          ),

          // Quick Add Floating CTA
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: InkWell(
              onTap: () => onDestinationSelected(2),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.aiGoldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiGold.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'عملية سريعة',
                      style: TextStyle(
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
                      AppTheme.aiGold.withValues(alpha: 0.18),
                      AppTheme.aiGold.withValues(alpha: 0.04),
                    ],
                    begin: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                    end: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.aiGold.withValues(alpha: 0.45) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.aiGold.withValues(alpha: 0.08),
                      blurRadius: 12,
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
                    color: isSelected ? AppTheme.aiGold : AppTheme.aiTextSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.aiGold : AppTheme.aiTextSecondary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

