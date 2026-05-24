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
import 'smart_calculator_screen.dart';

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
    final copy = AppCopy.of(context);
    final localeKey = Localizations.localeOf(context).languageCode;
    final screens = <Widget>[
      const DashboardScreen(),
      const InventoryScreen(),
      const SizedBox(),
      const SalesHistoryScreen(),
      const SmartCalculatorScreen(),
      const ReportsScreen(),
    ];

    return KeyedSubtree(
      key: ValueKey('main-nav-$localeKey'),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: screens,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                indicatorColor: AppTheme.accentBlue.withValues(alpha: 0.1),
                selectedIndex: _index,
                onDestinationSelected: _onDestinationSelected,
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined, size: 20),
                    selectedIcon: const Icon(Icons.dashboard, color: AppTheme.accentBlue),
                    label: copy.t('navDashboard'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.inventory_2_outlined, size: 20),
                    selectedIcon: const Icon(Icons.inventory_2, color: AppTheme.accentBlue),
                    label: copy.t('navInventory'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    selectedIcon: const Icon(Icons.add_circle, color: AppTheme.accentBlue),
                    label: copy.t('navAdd'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    selectedIcon: const Icon(Icons.receipt_long, color: AppTheme.accentBlue),
                    label: copy.t('navTransactions'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                    selectedIcon: const Icon(Icons.auto_awesome, color: AppTheme.accentBlue),
                    label: copy.isEnglish ? 'Smart' : 'ذكي', // Smart Calculator
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.analytics_outlined, size: 20),
                    selectedIcon: const Icon(Icons.analytics, color: AppTheme.accentBlue),
                    label: copy.t('navReports'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

  }
}
