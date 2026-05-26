import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../widgets/command_dock.dart';
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
          child: CommandDock(
            selectedIndex: _index,
            onDestinationSelected: _onDestinationSelected,
          ),
        ),
      ),
    );

  }
}
