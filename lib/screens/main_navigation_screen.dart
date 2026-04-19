import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_theme.dart';
import 'add_product_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'invoice_form_screen.dart';
import 'reports_screen.dart';
import 'sales_history_screen.dart';

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.inventory),
                title: Text(copy.t('addProduct')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddProductScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(copy.t('createInvoice')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceFormScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text(copy.t('addCustomer')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomersScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final copy = AppCopy.of(context);
    final localeKey = Localizations.localeOf(context).languageCode;
    final screens = <Widget>[
      const DashboardScreen(),
      const InventoryScreen(),
      const SizedBox(),
      const SalesHistoryScreen(),
      const ReportsScreen(),
    ];

    return KeyedSubtree(
      key: ValueKey('main-nav-$localeKey'),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: screens,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceFor(context)
                  .withValues(alpha: isDark ? 0.95 : 0.98),
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              border: Border.all(
                color: isDark
                    ? AppTheme.borderFor(context)
                    : AppTheme.borderFor(context).withValues(alpha: 0.95),
              ),
              boxShadow: [
                ...AppTheme.softShadow(context),
                if (!isDark)
                  BoxShadow(
                    color: AppTheme.brandBlue.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: AppTheme.accent.withValues(
                alpha: isDark ? 0.16 : 0.12,
              ),
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: copy.t('navDashboard'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: copy.t('navInventory'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.add_circle_outline),
                  selectedIcon: const Icon(Icons.add_circle),
                  label: copy.t('navAdd'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: copy.t('navTransactions'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.analytics_outlined),
                  selectedIcon: const Icon(Icons.analytics),
                  label: copy.t('navReports'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
