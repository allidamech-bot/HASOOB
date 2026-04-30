import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/customer_repository.dart';

class CustomerStatementScreen extends StatefulWidget {
  const CustomerStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();

  String get _businessId => AuthRepository.instance.currentUser?.businessId ?? AuthRepository.fallbackBusinessId;

  late Future<Map<String, dynamic>> _statementFuture;

  @override
  void initState() {
    super.initState();
    _statementFuture =
        _customerRepository.getCustomerStatement(_businessId, widget.customerId);
  }

  Future<void> _refresh() async {
    setState(() {
      _statementFuture =
          _customerRepository.getCustomerStatement(_businessId, widget.customerId);
    });
    await _statementFuture;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.customerStatementTitle(widget.customerName))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statementFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final customer = data['customer'] as Map<String, dynamic>;
            final invoices =
                data['invoices'] as List<Map<String, dynamic>>;
            final payments =
                data['payments'] as List<Map<String, dynamic>>;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['name']?.toString() ??
                              widget.customerName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if ((customer['phone']?.toString() ?? '').isNotEmpty)
                          Text('${copy.t('phone')}: ${customer['phone']}'),
                        if ((customer['notes']?.toString() ?? '').isNotEmpty)
                          Text('${copy.t('notes')}: ${customer['notes']}'),
                        const SizedBox(height: 12),
                        _summaryRow(
                          copy.t('total'),
                          AppFormatters.currency(
                            _toDouble(data['total_invoiced']),
                          ),
                        ),
                        _summaryRow(
                          copy.t('paid'),
                          AppFormatters.currency(
                            _toDouble(data['total_paid']),
                          ),
                          color: AppTheme.success,
                        ),
                        _summaryRow(
                          copy.t('remaining'),
                          AppFormatters.currency(
                            _toDouble(data['total_remaining']),
                          ),
                          color: _toDouble(data['total_remaining']) > 0
                              ? AppTheme.warning
                              : AppTheme.success,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  copy.t('customerInvoices'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (invoices.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                        child: Text(copy.t('noCustomerInvoices')),
                      ),
                    ),
                  )
                else
                  ...invoices.map(
                    (invoice) => Card(
                      child: ListTile(
                        title: Text(
                          invoice['invoice_number']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${copy.t('status')}: ${invoice['status']} - '
                          '${AppFormatters.dateTimeString(invoice['issue_date']?.toString())}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(_toDouble(invoice['total'])),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${copy.t('remainingAmount')} ${AppFormatters.currency(_toDouble(invoice['remaining_amount']))}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _toDouble(invoice['remaining_amount']) > 0
                                    ? AppTheme.warning
                                    : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  copy.t('customerPayments'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                        child: Text(copy.t('noCustomerPayments')),
                      ),
                    ),
                  )
                else
                  ...payments.map(
                    (payment) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.payments_rounded,
                          color: AppTheme.success,
                        ),
                        title: Text(
                          AppFormatters.currency(_toDouble(payment['amount'])),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${payment['payment_method']} - '
                          '${AppFormatters.dateTimeString(payment['payment_date']?.toString())}',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
