import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../data/repositories/customer_repository.dart';
import 'customer_statement_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();

  String get _businessId => BusinessContext.businessId;

  Future<void> _refresh() async {
    await _customerRepository.getCustomers(_businessId);
  }

  Future<void> _openCustomerForm([Map<String, dynamic>? customer]) async {
    final copy = AppCopy.of(context);
    final nameController =
        TextEditingController(text: customer?['name']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: customer?['phone']?.toString() ?? '');
    final notesController =
        TextEditingController(text: customer?['notes']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          customer == null ? copy.t('addCustomerTitle') : copy.t('editCustomerTitle'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: copy.t('addCustomer')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: copy.t('phone')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: copy.t('addressOrNotes'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _customerRepository.saveCustomer(_businessId, {
                  'id': customer?['id'],
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'notes': notesController.text,
                  'created_at': customer?['created_at'],
                });
                if (!context.mounted) return;
                Navigator.pop(context, true);
              } catch (error) {
                if (!context.mounted) return;
                AppMessages.error(context, '$error');
              }
            },
            child: Text(copy.t('save')),
          ),
        ],
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      AppMessages.success(
        context,
        customer == null ? copy.t('customerAdded') : copy.t('customerUpdated'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('customersTitle')),
        actions: [
          IconButton(
            onPressed: () => _openCustomerForm(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCustomerForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(copy.t('newCustomer')),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _customerRepository.watchCustomers(_businessId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.danger,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            copy.t('loadCustomersError'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final customers = snapshot.data ?? const <Map<String, dynamic>>[];
            if (customers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(copy.t('noCustomersYet'))),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: customers.map((customer) {
                final name = customer['name']?.toString() ?? '';
                final phone = customer['phone']?.toString() ?? '';
                final outstanding = _toDouble(customer['outstanding_balance']);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(name.isEmpty ? '?' : name.substring(0, 1)),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      copy.customerBalanceLine(
                        phone,
                        outstanding.toStringAsFixed(2),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _openCustomerForm(customer),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerStatementScreen(
                            customerId: customer['id'].toString(),
                            customerName: name,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
