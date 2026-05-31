import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../data/repositories/invoice_repository.dart';
import '../widgets/premium/premium_card.dart';
import 'customer_statement_screen.dart';

class CollectionCenterScreen extends StatefulWidget {
  const CollectionCenterScreen({super.key});

  @override
  State<CollectionCenterScreen> createState() => _CollectionCenterScreenState();
}

class _CollectionCenterScreenState extends State<CollectionCenterScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  bool _isLoading = true;
  String? _error;

  double _totalOverdue = 0.0;
  int _overdueInvoicesCount = 0;
  int _customersWithOverdue = 0;

  double _agingCurrent = 0.0;
  double _aging1to30 = 0.0;
  double _aging31to60 = 0.0;
  double _aging61to90 = 0.0;
  double _aging90Plus = 0.0;

  List<Map<String, dynamic>> _customerRisks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final businessId = BusinessContext.businessId;
      final invoices = await _invoiceRepository.getInvoices(businessId);
      final customers = await _invoiceRepository.getCustomers(businessId);

      final now = DateTime.now();

      _totalOverdue = 0.0;
      _overdueInvoicesCount = 0;

      _agingCurrent = 0.0;
      _aging1to30 = 0.0;
      _aging31to60 = 0.0;
      _aging61to90 = 0.0;
      _aging90Plus = 0.0;

      final Map<String, Map<String, dynamic>> customerRiskMap = {};

      for (var c in customers) {
        final cid = c['id']?.toString() ?? '';
        customerRiskMap[cid] = {
          'id': cid,
          'name': c['name']?.toString() ?? '',
          'phone': c['phone']?.toString() ?? '',
          'totalUnpaid': 0.0,
          'overdueAmount': 0.0,
          'lastInvoiceDate': null,
        };
      }

      for (final inv in invoices) {
        if (inv.status == 'unpaid' && inv.remainingAmount > 0) {
          final amt = inv.remainingAmount;
          int daysOverdue = 0;
          bool isOverdue = false;

          if (inv.dueDate != null && inv.dueDate!.isBefore(now)) {
            daysOverdue = now.difference(inv.dueDate!).inDays;
            isOverdue = true;
            _totalOverdue += amt;
            _overdueInvoicesCount++;
          }

          if (daysOverdue <= 0) {
            _agingCurrent += amt;
          } else if (daysOverdue <= 30) {
            _aging1to30 += amt;
          } else if (daysOverdue <= 60) {
            _aging31to60 += amt;
          } else if (daysOverdue <= 90) {
            _aging61to90 += amt;
          } else {
            _aging90Plus += amt;
          }

          // Link to customer
          final cid = inv.customerName; // Due to DB structure, customerName often stores customer_id or name
          // We must find the correct customer in map
          String targetCid = '';
          for (final entry in customerRiskMap.entries) {
            if (entry.value['id'] == cid || entry.value['name'] == cid) {
              targetCid = entry.key;
              break;
            }
          }

          if (targetCid.isNotEmpty) {
            final cMap = customerRiskMap[targetCid]!;
            cMap['totalUnpaid'] += amt;
            if (isOverdue) {
              cMap['overdueAmount'] += amt;
            }
            DateTime? lastDate = cMap['lastInvoiceDate'];
            if (lastDate == null || inv.issueDate.isAfter(lastDate)) {
              cMap['lastInvoiceDate'] = inv.issueDate;
            }
          }
        }
      }

      _customerRisks = customerRiskMap.values
          .where((c) => c['totalUnpaid'] > 0)
          .toList()
        ..sort((a, b) => b['overdueAmount'].compareTo(a['overdueAmount']));

      _customersWithOverdue = _customerRisks.where((c) => c['overdueAmount'] > 0).length;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getRiskLevel(double overdueAmount, AppCopy copy) {
    if (overdueAmount <= 0) return copy.t('riskLow');
    if (overdueAmount < 1000) return copy.t('riskMedium');
    if (overdueAmount < 5000) return copy.t('riskHigh');
    return copy.t('riskCritical');
  }

  Color _getRiskColor(double overdueAmount) {
    if (overdueAmount <= 0) return AppTheme.aiGreen;
    if (overdueAmount < 1000) return AppTheme.aiGold;
    if (overdueAmount < 5000) return Colors.orange;
    return AppTheme.aiRed;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      appBar: AppBar(
        title: Text(
          copy.t('collectionCenterTitle'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppTheme.aiNavy,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.aiGold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.aiRed)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.aiGold,
                  backgroundColor: AppTheme.aiCard,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildExecutiveSummary(copy, isDesktop),
                      const SizedBox(height: 32),
                      Text(
                        copy.t('agingBuckets'),
                        style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 16),
                      _buildAgingBucketsRow(copy),
                      const SizedBox(height: 32),
                      Text(
                        copy.t('customerRisk'),
                        style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 16),
                      if (_customerRisks.isEmpty)
                        PremiumCard(
                          padding: const EdgeInsets.all(32),
                          border: Border.all(color: AppTheme.aiCardBorder),
                          child: Center(
                            child: Text(
                              copy.t('noOverdueInvoices'),
                              style: const TextStyle(color: AppTheme.aiTextSecondary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        ..._customerRisks.map((c) => _buildCustomerCard(c, copy)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildExecutiveSummary(AppCopy copy, bool isDesktop) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildSummaryCard(copy.t('totalOverdue'), AppFormatters.currency(_totalOverdue), AppTheme.aiRed, isDesktop),
        _buildSummaryCard(copy.t('overdueInvoicesCount'), '$_overdueInvoicesCount', AppTheme.aiGold, isDesktop),
        _buildSummaryCard(copy.t('customersWithOverdue'), '$_customersWithOverdue', AppTheme.aiBlue, isDesktop),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, bool isDesktop) {
    return Container(
      width: isDesktop ? 240 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildAgingBucketsRow(AppCopy copy) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildAgingBucket(copy.t('agingCurrent'), _agingCurrent, AppTheme.aiGreen),
          const SizedBox(width: 12),
          _buildAgingBucket(copy.t('aging1To30'), _aging1to30, AppTheme.aiGold),
          const SizedBox(width: 12),
          _buildAgingBucket(copy.t('aging31To60'), _aging31to60, Colors.orange),
          const SizedBox(width: 12),
          _buildAgingBucket(copy.t('aging61To90'), _aging61to90, AppTheme.aiRed.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          _buildAgingBucket(copy.t('aging90Plus'), _aging90Plus, AppTheme.aiRed),
        ],
      ),
    );
  }

  Widget _buildAgingBucket(String label, double amount, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            AppFormatters.currency(amount),
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c, AppCopy copy) {
    final double overdue = c['overdueAmount'];
    final double total = c['totalUnpaid'];
    final riskLabel = _getRiskLevel(overdue, copy);
    final riskColor = _getRiskColor(overdue);
    final lastDate = c['lastInvoiceDate'] as DateTime?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: riskColor.withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: riskColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'], style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        '${copy.t('unpaidBalance')}: ${AppFormatters.currency(total)}',
                        style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 13),
                      ),
                      if (lastDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${copy.t('lastInvoiceDate')}: ${AppFormatters.dateString(lastDate)}',
                          style: const TextStyle(color: AppTheme.aiTextMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(riskLabel, style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppFormatters.currency(overdue),
                      style: TextStyle(color: riskColor, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.aiCardBorder, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(customerId: c['id'], customerName: c['name'])));
                  },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: Text(copy.t('details')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    final message = copy.whatsappReminderTemplate(c['name'], AppFormatters.currency(overdue));
                    Clipboard.setData(ClipboardData(text: message));
                    AppMessages.success(context, 'تم نسخ الرسالة بنجاح.');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(copy.t('copyWhatsApp')),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.aiGreen, foregroundColor: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
