import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hasoob_app/core/app_theme.dart';
import 'package:hasoob_app/features/ai_accountant/presentation/screens/ai_accountant_screen.dart';
import 'package:hasoob_app/widgets/command_dock.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';
import 'smart_calculator_screen.dart';

class AiWorkspaceScreen extends StatefulWidget {
  const AiWorkspaceScreen({super.key});

  @override
  State<AiWorkspaceScreen> createState() => _AiWorkspaceScreenState();
}

class _AiWorkspaceScreenState extends State<AiWorkspaceScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AiAccountantScreen(workspaceMode: true),
    DashboardScreen(),
    InventoryScreen(),
    SalesHistoryScreen(),
    SmartCalculatorScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          if (!isDesktop) {
            return IndexedStack(
              index: _selectedIndex,
              children: _screens,
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesktopSidebar(context),
              const VerticalDivider(width: 1, thickness: 1, color: AppTheme.aiCardBorder),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          if (isDesktop) return const SizedBox.shrink();

          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: CommandDock(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    final items = [
      _SidebarNavItemData(
        index: 0,
        icon: Icons.psychology_rounded,
        label: 'AI Accountant',
      ),
      _SidebarNavItemData(
        index: 1,
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
      ),
      _SidebarNavItemData(
        index: 2,
        icon: Icons.inventory_2_rounded,
        label: 'Inventory',
      ),
      _SidebarNavItemData(
        index: 3,
        icon: Icons.receipt_long_rounded,
        label: 'Transactions',
      ),
      _SidebarNavItemData(
        index: 4,
        icon: Icons.auto_awesome_rounded,
        label: 'Smart Advisor',
      ),
      _SidebarNavItemData(
        index: 5,
        icon: Icons.analytics_rounded,
        label: 'Reports',
      ),
      _SidebarNavItemData(
        index: 6,
        icon: Icons.settings_suggest_rounded,
        label: 'Settings',
      ),
    ];

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.aiNavy,
        border: Border(
          right: BorderSide(color: AppTheme.aiCardBorder, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: const [
                  Icon(Icons.psychology_rounded, color: AppTheme.aiGold, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'AI Workspace',
                    style: TextStyle(color: AppTheme.aiGold, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(color: AppTheme.aiCardBorder.withValues(alpha: 0.5), thickness: 1.2),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: items.map((item) {
                final isSelected = _selectedIndex == item.index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _WorkspaceSidebarItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () => _onDestinationSelected(item.index),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItemData {
  final int index;
  final IconData icon;
  final String label;

  const _SidebarNavItemData({
    required this.index,
    required this.icon,
    required this.label,
  });
}

class _WorkspaceSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorkspaceSidebarItem({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.aiGold.withValues(alpha: 0.14),
                      AppTheme.aiGold.withValues(alpha: 0.03),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.aiGold.withValues(alpha: 0.34) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.aiGold : AppTheme.aiTextSecondary,
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.aiGold : AppTheme.aiTextSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: AppTheme.aiGoldGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
