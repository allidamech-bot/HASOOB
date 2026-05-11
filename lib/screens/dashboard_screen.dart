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
import '../data/services/sync_manager.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/sync_health_card.dart';

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
    _snapshot = _reportService.buildSnapshot(businessId: businessId).timeout(const Duration(seconds: 8));
    _restoreStatus = CloudSyncService.instance.getLocalRestoreStatus();
  }

  Future<void> _refresh() async {
    final businessId = BusinessContext.businessId;
    setState(() {
      _snapshot = _reportService.buildSnapshot(businessId: businessId).timeout(const Duration(seconds: 8));
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
          const SyncStatusIndicator(),
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
      floatingActionButton: ListenableBuilder(
        listenable: SyncManager.instance,
        builder: (context, _) {
          final manager = SyncManager.instance;
          if (!manager.syncRequested && !manager.isRunning) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: manager.isRunning ? null : () => manager.runSync(),
            backgroundColor: manager.isRunning
                ? AppTheme.textSecondaryFor(context)
                : AppTheme.accent,
            icon: manager.isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(
              manager.isRunning ? copy.t('syncRunning') : copy.t('syncNow'),
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ReportsSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 180),
                  Card(
                    color: Colors.red.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Error', style: TextStyle(color: Colors.red, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

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
            // dashboard content here...