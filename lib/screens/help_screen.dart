import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.t('helpTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _heroCard(context, copy),
          const SizedBox(height: 20),
          _guideCard(
            context,
            icon: Icons.dashboard_rounded,
            title: copy.t('helpDashboardTitle'),
            body: copy.t('helpDashboardBody'),
          ),
          const SizedBox(height: 12),
          _guideCard(
            context,
            icon: Icons.inventory_2_rounded,
            title: copy.t('helpInventoryTitle'),
            body: copy.t('helpInventoryBody'),
          ),
          const SizedBox(height: 12),
          _guideCard(
            context,
            icon: Icons.receipt_long_rounded,
            title: copy.t('helpDocumentsTitle'),
            body: copy.t('helpDocumentsBody'),
          ),
          const SizedBox(height: 12),
          _guideCard(
            context,
            icon: Icons.request_quote_rounded,
            title: copy.t('helpInvoicesTitle'),
            body: copy.t('helpInvoicesBody'),
          ),
          const SizedBox(height: 12),
          _guideCard(
            context,
            icon: Icons.sync_rounded,
            title: copy.t('helpSyncTitle'),
            body: copy.t('helpSyncBody'),
          ),
          const SizedBox(height: 12),
          _guideCard(
            context,
            icon: Icons.tips_and_updates_rounded,
            title: copy.t('helpTipTitle'),
            body: copy.t('helpTipBody'),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context, AppCopy copy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.16),
            AppTheme.surfaceFor(context),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('helpHeroTitle'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.t('helpHeroBody'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryFor(context),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _guideCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryFor(context),
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
