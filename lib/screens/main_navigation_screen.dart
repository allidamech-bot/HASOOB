import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_copy.dart';
import '../core/app_theme.dart';
import '../widgets/command_dock.dart';
import '../widgets/desktop_sidebar.dart';
import 'add_product_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'invoice_form_screen.dart';
import 'reports_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';
import 'smart_calculator_screen.dart';
import '../features/command_dock/presentation/widgets/command_search_overlay.dart';
import '../features/ai_accountant/presentation/screens/ai_accountant_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  void _onDestinationSelected(int index) {
    if (index == 2) {
      _openAddMenu();
      return;
    }
    setState(() {
      _index = index;
    });
  }

  void _openAddMenu() {
    final copy = AppCopy.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.aiCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.aiCardBorder, width: 1),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.aiCardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded,
                          color: AppTheme.aiBlue, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        copy.isEnglish ? 'Quick Add' : 'إضافة سريعة',
                        style: const TextStyle(
                          color: AppTheme.aiTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _aiListTile(
                  sheetContext: sheetContext,
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppTheme.aiBlue,
                  label: copy.t('addProduct'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddProductScreen()),
                    );
                  },
                ),
                _aiListTile(
                  sheetContext: sheetContext,
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppTheme.aiGold,
                  label: copy.t('createInvoice'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InvoiceFormScreen()),
                    );
                  },
                ),
                _aiListTile(
                  sheetContext: sheetContext,
                  icon: Icons.person_add_rounded,
                  iconColor: AppTheme.aiGreen,
                  label: copy.t('addCustomer'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomersScreen()),
                    );
                  },
                ),
                _aiListTile(
                  sheetContext: sheetContext,
                  icon: Icons.psychology_outlined,
                  iconColor: const Color(0xFFD4AF37),
                  label: copy.isEnglish ? 'AI Accountant' : 'المحاسب الذكي',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AiAccountantScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aiListTile({
    required BuildContext sheetContext,
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.aiTextMuted, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeKey = Localizations.localeOf(context).languageCode;
    final screens = <Widget>[
      const DashboardScreen(),
      const InventoryScreen(),
      const SizedBox(),
      const SalesHistoryScreen(),
      const SmartCalculatorScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return KeyedSubtree(
      key: ValueKey('main-nav-$localeKey'),
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent && 
              event.logicalKey == LogicalKeyboardKey.keyK && 
              HardwareKeyboard.instance.isControlPressed) {
            CommandSearchOverlay.show(context);
          }
        },
        child: Scaffold(
        backgroundColor: AppTheme.aiDeep,
        extendBody: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;
            if (isDesktop) {
              return Directionality(
                textDirection: localeKey == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                child: Row(
                  children: [
                    DesktopSidebar(
                      selectedIndex: _index,
                      onDestinationSelected: _onDestinationSelected,
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: screens,
                      ),
                    ),
                  ],
                ),
              );
            }

            return IndexedStack(
              index: _index,
              children: screens,
            );
          },
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;
            if (isDesktop) return const SizedBox.shrink();

            return SafeArea(
              minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: CommandDock(
                selectedIndex: _index,
                onDestinationSelected: _onDestinationSelected,
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
