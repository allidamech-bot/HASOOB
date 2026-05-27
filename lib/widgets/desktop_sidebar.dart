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
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.aiNavy,
        border: Border(
          left: BorderSide(
            color: AppTheme.aiCardBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.aiBlueGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.aiBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Text(
                  'HASOOB',
                  style: TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: copy.t('dashboard'),
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.inventory_2_rounded,
                  label: copy.t('inventory'),
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.receipt_long_rounded,
                  label: copy.t('sales'),
                  isSelected: selectedIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.calculate_rounded,
                  label: copy.t('smartCalculator'),
                  isSelected: selectedIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
                const SizedBox(height: 8),
                _SidebarItem(
                  icon: Icons.bar_chart_rounded,
                  label: copy.t('reports'),
                  isSelected: selectedIndex == 5,
                  onTap: () => onDestinationSelected(5),
                ),
              ],
            ),
          ),
          
          // Quick Add Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: InkWell(
              onTap: () => onDestinationSelected(2),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.aiBlueGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.aiBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      copy.isEnglish ? 'Quick Add' : 'إضافة سريعة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.aiBlue.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.aiBlue.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.aiBlue : AppTheme.aiTextSecondary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.aiBlue : AppTheme.aiTextSecondary,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
