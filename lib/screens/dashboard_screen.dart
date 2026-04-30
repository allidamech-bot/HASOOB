import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../data/database/database_helper.dart';
import '../data/services/auth_service.dart';
import '../data/services/cloud_sync_service.dart';
import '../data/services/reports/report_models.dart';
import '../data/services/reports/report_service.dart';
import '../widgets/app_section_header.dart';
import '../widgets/metric_card.dart';
import 'add_product_screen.dart';
import 'business_profile_screen.dart';
import 'customers_screen.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportService _reportService = const ReportService();
  late Future<ReportsSnapshot> _snapshot;
  late Future<Map<String, dynamic>> _restoreStatus;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    final businessId = BusinessContext.businessId;
    _snapshot = _reportService.buildSnapshot(businessId: businessId);
    _restoreStatus = CloudSyncService.instance.getLocalRestoreStatus();
  }

  Future<void> _refresh() async {
    final businessId = BusinessContext.businessId;
    setState(() {
      _snapshot = _reportService.buildSnapshot(businessId: businessId);
      _restoreStatus = CloudSyncService.instance.getLocalRestoreStatus();
    });
    await _snapshot;
  }

  Future<void> _restoreFromCloud() async {
    final copy = AppCopy.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.t('restoreDialogTitle')),
        content: Text(copy.t('restoreDialogBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.t('continue')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isRestoring = true);

    try {
      final businessId = BusinessContext.businessId;
      final isLocalEmpty = await DBHelper.isLocalBusinessDataEmpty(businessId);
      if (!isLocalEmpty) {
        throw Exception(copy.t('restoreOnlyWhenEmpty'));
      }

      final products = await CloudSyncService.instance.fetchProducts(businessId);
      if (products.isEmpty) {
        throw Exception(copy.t('cloudProductsMissing'));
      }

      final accounts = await CloudSyncService.instance.fetchAccounts(businessId);
      final salesRecords = await CloudSyncService.instance.fetchSalesRecords(businessId);
      final journalEntries = await CloudSyncService.instance.fetchJournalEntries(businessId);

      final restoredCount = await DBHelper.restoreCloudSnapshotIfLocalEmpty(
        businessId: businessId,
        products: products,
        accounts: accounts,
        salesRecords: salesRecords,
        journalEntries: journalEntries,
      );

      await CloudSyncService.instance.markLocalRestoreUsed();
      await _refresh();

      if (!mounted) return;
      AppMessages.success(context, copy.dashboardRestoreCount(restoredCount));
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('loadDashboardRestoreError')}\n$error');
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('dashboardTitle')),
        actions: [
          IconButton(
            tooltip: copy.t('businessProfile'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
              );
            },
            icon: const Icon(Icons.apartment_rounded),
          ),
          IconButton(
            tooltip: copy.t('settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: copy.t('logout'),
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ReportsSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            final data = snapshot.data!;
            final lowStockPreview = data.lowStockItems.take(3).toList();
            final recentSalesPreview = data.recentSales.take(3).toList();

            return SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _heroCard(context, copy),
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: copy.t('overview'),
                    subtitle: copy.t('overviewSubtitle'),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(context).scale(1);
                      final crossAxisCount = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth < 420
                              ? 1
                              : 2;
                      final baseHeight = constraints.maxWidth < 360 ? 162.0 : 172.0;
                      final cardHeight =
                          baseHeight + ((textScale - 1) * 22).clamp(0, 26);

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisExtent: cardHeight,
                        children: [
                          MetricCard(
                            title: copy.t('totalProducts'),
                            value: AppFormatters.number(data.totalProducts),
                            icon: Icons.inventory_2_rounded,
                          ),
                          MetricCard(
                            title: copy.t('totalSales'),
                            value: AppFormatters.currency(data.totalSales),
                            icon: Icons.point_of_sale_rounded,
                          ),
                          MetricCard(
                            title: copy.t('estimatedProfit'),
                            value: AppFormatters.currency(data.netProfitEstimate),
                            icon: Icons.trending_up_rounded,
                            accentColor: AppTheme.success,
                          ),
                          MetricCard(
                            title: copy.t('lowStockCount'),
                            value: AppFormatters.number(data.lowStockItems.length),
                            icon: Icons.warning_amber_rounded,
                            accentColor: AppTheme.warning,
                            caption: data.lowStockItems.isEmpty
                                ? copy.t('noAlertsNow')
                                : copy.t('needsAttentionSoon'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: copy.t('quickActions'),
                    subtitle: copy.t('quickActionsSubtitle'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _quickAction(
                          context,
                          icon: Icons.add_box_rounded,
                          title: copy.t('addProduct'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddProductScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickAction(
                          context,
                          icon: Icons.receipt_long_rounded,
                          title: copy.t('newInvoice'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickAction(
                          context,
                          icon: Icons.person_add_alt_1_rounded,
                          title: copy.t('newCustomer'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CustomersScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _restoreStatus,
                      builder: (context, restoreSnapshot) {
                        final restoreData = restoreSnapshot.data;
                        final hasRestored = restoreData?['has_restored'] == true;
                        final lastRestoreAt =
                            restoreData?['last_restore_at']?.toString();

                        return Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _iconShell(
                                  context,
                                  Icons.cloud_download_rounded,
                                  AppTheme.info,
                                ),
                                title: Text(
                                  copy.t('restoreFromCloud'),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(copy.t('restoreFromCloudSubtitle')),
                                trailing: _isRestoring
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                                onTap: _isRestoring ? null : _restoreFromCloud,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: hasRestored
                                      ? AppTheme.success.withValues(alpha: 0.08)
                                      : AppTheme.surfaceAltFor(context),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                  border: Border.all(
                                    color: hasRestored
                                        ? AppTheme.success.withValues(alpha: 0.24)
                                        : AppTheme.borderFor(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      hasRestored
                                          ? Icons.cloud_done_rounded
                                          : Icons.cloud_off_rounded,
                                      color: hasRestored
                                          ? AppTheme.success
                                          : AppTheme.textSecondaryFor(context),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasRestored
                                                ? copy.t('restoreUsed')
                                                : copy.t('restoreUnused'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (lastRestoreAt != null &&
                                              lastRestoreAt.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              copy.dashboardLastRestore(
                                                AppFormatters.dateTimeString(lastRestoreAt),
                                              ),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: copy.t('stockAlerts'),
                    subtitle: copy.t('stockAlertsSubtitle'),
                  ),
                  const SizedBox(height: 12),
                  if (data.lowStockItems.isEmpty)
                    _emptyCard(
                      context,
                      icon: Icons.inventory_2_outlined,
                      text: copy.t('noLowStockNow'),
                    )
                  else ...[
                    Card(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      child: ListTile(
                        leading: _iconShell(
                          context,
                          Icons.crisis_alert_rounded,
                          AppTheme.warning,
                        ),
                        title: Text(
                          copy.dashboardLowStockCount(data.lowStockItems.length),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(copy.t('reviewLowStock')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...lowStockPreview.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            leading: _iconShell(
                              context,
                              item.isOutOfStock
                                  ? Icons.remove_shopping_cart_rounded
                                  : Icons.warning_amber_rounded,
                              item.isOutOfStock
                                  ? AppTheme.danger
                                  : AppTheme.warning,
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              copy.dashboardStockLine(
                                item.stockQty,
                                item.unit,
                                item.lowStockThreshold,
                              ),
                            ),
                            trailing: _pill(
                              item.isOutOfStock
                                  ? copy.t('outOfStock')
                                  : copy.t('lowStock'),
                              item.isOutOfStock ? AppTheme.danger : AppTheme.warning,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: copy.t('recentSales'),
                    subtitle: copy.t('recentSalesSubtitle'),
                  ),
                  const SizedBox(height: 12),
                  if (data.recentSales.isEmpty)
                    _emptyCard(
                      context,
                      icon: Icons.sell_outlined,
                      text: copy.t('noSalesYet'),
                    )
                  else ...[
                    Card(
                      child: ListTile(
                        leading: _iconShell(
                          context,
                          Icons.monitor_heart_rounded,
                          AppTheme.info,
                        ),
                        title: Text(
                          copy.dashboardRecentSalesCount(recentSalesPreview.length),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(copy.t('recentSalesSubtitle')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...recentSalesPreview.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            leading: _iconShell(
                              context,
                              Icons.sell_rounded,
                              AppTheme.info,
                            ),
                            title: Text(
                              row['product_name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              copy.dashboardRecentSaleSubtitle(
                                customerName: row['customer_name']?.toString() ?? '',
                                qty: row['qty'],
                                date: AppFormatters.dateTimeString(
                                  row['date']?.toString(),
                                ),
                              ),
                            ),
                            trailing: Text(
                              AppFormatters.currency(_toDouble(row['total_sale'])),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, AppCopy copy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.18),
            AppTheme.surfaceFor(context),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('professionalDashboard'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  copy.t('dashboardHero'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryFor(context),
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _iconShell(context, Icons.dashboard_customize_rounded, AppTheme.accent),
        ],
      ),
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltFor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderFor(context)),
        ),
        child: Column(
          children: [
            _iconShell(context, icon, AppTheme.accent),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _iconShell(context, icon, AppTheme.accent),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryFor(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconShell(BuildContext context, IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
