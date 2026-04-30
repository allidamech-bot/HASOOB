import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_theme.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/invoice_model.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
  });

  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    final repository = InvoiceRepository();
    final copy = AppCopy.of(context);
    final businessId = AuthRepository.instance.currentUser?.businessId ?? AuthRepository.fallbackBusinessId;

    return Scaffold(
      appBar: AppBar(title: Text(copy.t('invoiceDetailsTitle'))),
      body: StreamBuilder<InvoiceModel?>(
        stream: repository.watchInvoiceById(businessId, invoiceId),
        builder: (context, invoiceSnapshot) {
          if (invoiceSnapshot.connectionState == ConnectionState.waiting &&
              !invoiceSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoice = invoiceSnapshot.data;
          if (invoice == null) {
            return Center(child: Text(copy.t('invoiceNotFound')));
          }

          final currencyCode = invoice.currencyCode;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: repository.watchInvoiceItems(businessId, invoiceId),
            builder: (context, itemsSnapshot) {
              final items = itemsSnapshot.data ?? const <Map<String, dynamic>>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNumber,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          _detailRow(
                            context,
                            copy.t('customer'),
                            invoice.customerName.trim().isNotEmpty == true
                                ? invoice.customerName
                                : copy.documentsCustomerFallback(),
                          ),
                          _detailRow(
                            context,
                            copy.t('status'),
                            _statusLabel(invoice.status, copy),
                          ),
                          _detailRow(
                            context,
                            copy.t('invoiceDate'),
                            AppFormatters.dateTimeString(invoice.issueDate.toIso8601String()),
                          ),
                          _detailRow(
                            context,
                            copy.t('dueDate'),
                            invoice.dueDate != null
                                ? AppFormatters.dateTimeString(invoice.dueDate!.toIso8601String())
                                : '-',
                          ),
                          _detailRow(
                            context,
                            copy.t('currency'),
                            currencyCode?.trim().isEmpty ?? true ? '-' : currencyCode!,
                          ),
                          _detailRow(
                            context,
                            copy.t('notes'),
                            invoice.notes?.trim().isNotEmpty == true
                                ? invoice.notes!
                                : '-',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.t('items'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            Text(
                              copy.t('noItemsAvailable'),
                              style: TextStyle(
                                color: AppTheme.textSecondaryFor(context),
                              ),
                            )
                          else
                            ...items.map((item) {
                              final quantity = _toInt(item['quantity']);
                              final unitPrice = _toDouble(item['unit_price']);
                              final lineTotal = _toDouble(item['line_total']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAltFor(context),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.borderFor(context)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['product_name']?.toString() ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      copy
                                          .t('qtyPriceLine')
                                          .replaceAll('{qty}', '$quantity')
                                          .replaceAll(
                                            '{price}',
                                            AppFormatters.currency(
                                              unitPrice,
                                              currencyLabel: currencyCode,
                                            ),
                                          ),
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryFor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      copy
                                          .t('lineTotal')
                                          .replaceAll(
                                            '{value}',
                                            AppFormatters.currency(
                                              lineTotal,
                                              currencyLabel: currencyCode,
                                            ),
                                          ),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _summaryRow(context, copy.t('total'), invoice.total,
                              currencyCode: currencyCode),
                          const SizedBox(height: 8),
                          _summaryRow(context, copy.t('paid'), invoice.paidAmount,
                              currencyCode: currencyCode),
                          const SizedBox(height: 8),
                          _summaryRow(
                            context,
                            copy.t('remaining'),
                            invoice.remainingAmount,
                            currencyCode: currencyCode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    double value, {
    String? currencyCode,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          AppFormatters.currency(value, currencyLabel: currencyCode),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String _statusLabel(String status, AppCopy copy) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return copy.t('statusPaid');
      case 'partially_paid':
        return copy.t('statusPartiallyPaid');
      case 'overdue':
        return copy.t('statusOverdue');
      case 'issued':
        return copy.t('statusIssued');
      case 'draft':
        return copy.t('statusDraft');
      default:
        return status.trim().isEmpty ? copy.t('statusUnknown') : status;
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
