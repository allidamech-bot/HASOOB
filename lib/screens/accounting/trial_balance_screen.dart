import 'package:flutter/material.dart';

import '../../core/app_copy.dart';
import '../../core/app_formatters.dart';
import '../../core/app_theme.dart';
import '../../data/services/reports/report_models.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/metric_card.dart';

class TrialBalanceScreen extends StatelessWidget {
  const TrialBalanceScreen({
    super.key,
    required this.accounts,
    required this.summary,
  });

  final List<Map<String, dynamic>> accounts;
  final TrialBalanceSummary summary;

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _categoryLabel(String value, AppCopy copy) {
    switch (value) {
      case 'asset':
        return copy.t('asset');
      case 'liability':
        return copy.t('liability');
      case 'revenue':
        return copy.t('revenue');
      case 'expense':
        return copy.t('expense');
      default:
        return copy.t('account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('trialBalance')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionHeader(
            title: copy.t('trialBalanceSummary'),
            subtitle: copy.t('trialBalanceSummarySubtitle'),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              MetricCard(
                title: copy.t('totalDebit'),
                value: AppFormatters.currency(summary.totalDebit),
                icon: Icons.call_received_rounded,
                accentColor: AppTheme.success,
              ),
              MetricCard(
                title: copy.t('totalCredit'),
                value: AppFormatters.currency(summary.totalCredit),
                icon: Icons.call_made_rounded,
                accentColor: AppTheme.info,
              ),
              MetricCard(
                title: copy.t('entriesCount'),
                value: AppFormatters.number(summary.entriesCount),
                icon: Icons.receipt_long_rounded,
              ),
              MetricCard(
                title: copy.t('balanceStatus'),
                value: summary.isBalanced
                    ? copy.t('balanced')
                    : copy.t('unbalanced'),
                icon: summary.isBalanced
                    ? Icons.verified_rounded
                    : Icons.warning_amber_rounded,
                accentColor: summary.isBalanced ? AppTheme.success : AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    summary.isBalanced
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: summary.isBalanced ? AppTheme.success : AppTheme.warning,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.isBalanced
                          ? copy.t('balancedHelp')
                          : copy.t('unbalancedHelp'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppSectionHeader(
            title: copy.t('accounts'),
            subtitle: copy.t('accountsSubtitle'),
          ),
          const SizedBox(height: 12),
          ...accounts.map((account) {
            final balance = _toDouble(account['balance']);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (balance >= 0 ? AppTheme.success : AppTheme.info)
                      .withValues(alpha: 0.16),
                  child: Icon(
                    balance >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                    color: balance >= 0 ? AppTheme.success : AppTheme.info,
                  ),
                ),
                title: Text(
                  account['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  copy.trialBalanceAccountSubtitle(
                    account['code']?.toString() ?? '',
                    _categoryLabel(account['category']?.toString() ?? '', copy),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      balance >= 0 ? copy.t('debit') : copy.t('credit'),
                      style: TextStyle(
                        color: balance >= 0 ? AppTheme.success : AppTheme.info,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(balance.abs()),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
