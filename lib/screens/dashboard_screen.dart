import 'dart:async';
import 'package:flutter/material.dart';

import 'package:hasoob_app/core/app_copy.dart';
import 'package:hasoob_app/core/app_formatters.dart';
import 'package:hasoob_app/core/app_messages.dart';
import 'package:hasoob_app/core/app_theme.dart';
import 'package:hasoob_app/core/business/business_context.dart';
import 'package:hasoob_app/data/database/database_helper.dart';
import 'package:hasoob_app/data/services/auth_service.dart';
import 'package:hasoob_app/data/services/cloud_sync_service.dart';
import 'package:hasoob_app/data/services/reports/report_models.dart';
import 'package:hasoob_app/data/services/reports/report_service.dart';
import 'package:hasoob_app/core/utils/perf_logger.dart';
import 'package:hasoob_app/widgets/skeleton_loader.dart';
import 'package:hasoob_app/widgets/metric_card.dart';
import 'package:hasoob_app/screens/add_product_screen.dart';
import 'package:hasoob_app/screens/business_profile_screen.dart';
import 'package:hasoob_app/screens/customers_screen.dart';
import 'package:hasoob_app/screens/documents_screen.dart';
import 'package:hasoob_app/screens/settings_screen.dart';
import 'package:hasoob_app/widgets/premium/premium_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/widgets/sync_status_indicator.dart';
import 'package:hasoob_app/widgets/sync_health_card.dart';
import 'package:hasoob_app/widgets/local_mode_status_card.dart';
import 'package:firebase_core/firebase_core.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportService _reportService = const ReportService();
  ReportsSnapshot? _cachedData;
  Map<String, dynamic>? _restoreStatusData;
  bool _isRestoring = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    PerfLogger.logPageOpen('Dashboard');
    
    // Lazy load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final businessId = BusinessContext.businessId;
      
      // Load restore status and report snapshot in parallel with timeouts
      final results = await Future.wait([
        _reportService.buildSnapshot(businessId: businessId, forceRefresh: forceRefresh)
            .timeout(const Duration(seconds: 10)),
        CloudSyncService.instance.getLocalRestoreStatus()
            .timeout(const Duration(seconds: 5)),
      ]);

      if (mounted) {
        setState(() {
          _cachedData = results[0] as ReportsSnapshot;
          _restoreStatusData = results[1] as Map<String, dynamic>;
          _isLoading = false;
          PerfLogger.logDataLoaded('Dashboard');
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadData(forceRefresh: true);
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(copy.t('dashboardTitle'), style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        actions: [
          const SyncStatusIndicator(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: copy.t('businessProfile'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
              );
            },
            icon: const Icon(Icons.apartment_rounded, size: 20),
          ),
          IconButton(
            tooltip: copy.t('settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
          IconButton(
            tooltip: copy.t('logout'),
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
          const SizedBox(width: 8),
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
            onPressed: manager.isRunning ? null : () => manager.runSync(force: true),
            backgroundColor: manager.isRunning
                ? AppTheme.surfaceElevated
                : AppTheme.accentBlue,
            elevation: 8,
            icon: manager.isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white),
            label: Text(
              manager.isRunning ? copy.t('syncRunning') : copy.t('syncNow'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          // Background Glows removed for cleaner SaaS look

          RefreshIndicator(
            onRefresh: _refresh,
            displacement: 100,
            child: _buildBody(context, copy),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppCopy copy) {
    if (_isLoading && _cachedData == null) {
      return _buildSkeleton(context, copy);
    }
    
    if (_error != null && _cachedData == null) {
      return _buildErrorState(context, copy, _error);
    }

    return _buildContent(context, copy, _cachedData ?? ReportsSnapshot.empty());
  }

  Widget _buildContent(BuildContext context, AppCopy copy, ReportsSnapshot data) {
    final lowStockPreview = data.lowStockItems.take(3).toList();
    final recentSalesPreview = data.recentSales.take(3).toList();
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroCard(context, copy),
                const SizedBox(height: 16),
                if (Firebase.apps.isEmpty) ...[
                  const LocalModeStatusCard(),
                  const SizedBox(height: 16),
                ],
                const SyncHealthCard(),
                const SizedBox(height: 24),
                
                Text(
                  copy.t('overview'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: constraints.maxWidth < 400 ? 1.4 : 1.5,
                      children: [
                        MetricCard(
                          title: copy.t('totalProducts'),
                          value: AppFormatters.number(data.totalProducts),
                          icon: Icons.inventory_2_rounded,
                          accentColor: AppTheme.accentBlue,
                        ),
                        MetricCard(
                          title: copy.t('totalSales'),
                          value: AppFormatters.currency(data.totalSales),
                          icon: Icons.point_of_sale_rounded,
                          accentColor: Colors.cyan,
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
                          accentColor: Colors.amber,
                          caption: data.lowStockItems.isEmpty
                              ? copy.t('noAlertsNow')
                              : copy.t('needsAttentionSoon'),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                Text(
                  copy.t('quickActions'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _quickActionTile(
                        context,
                        icon: Icons.add_box_rounded,
                        title: copy.t('addProduct'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
                      ),
                      const SizedBox(width: 12),
                      _quickActionTile(
                        context,
                        icon: Icons.receipt_long_rounded,
                        title: copy.t('newInvoice'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
                      ),
                      const SizedBox(width: 12),
                      _quickActionTile(
                        context,
                        icon: Icons.person_add_alt_1_rounded,
                        title: copy.t('newCustomer'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                _buildRestoreCard(context, copy),
                
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _stockSection(context, copy, data, lowStockPreview)),
                      const SizedBox(width: 32),
                      Expanded(child: _salesSection(context, copy, data, recentSalesPreview)),
                    ],
                  )
                else ...[
                  _stockSection(context, copy, data, lowStockPreview),
                  const SizedBox(height: 32),
                  _salesSection(context, copy, data, recentSalesPreview),
                ],
                const SizedBox(height: 160),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stockSection(BuildContext context, AppCopy copy, ReportsSnapshot data, List<dynamic> preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(copy.t('stockAlerts'), copy.t('stockAlertsSubtitle')),
        const SizedBox(height: 16),
        if (data.lowStockItems.isEmpty)
          _emptyCard(context, icon: Icons.inventory_2_outlined, text: copy.t('noLowStockNow'))
        else ...[
          ...preview.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _iconBox(item.isOutOfStock ? Icons.remove_shopping_cart_rounded : Icons.warning_amber_rounded, 
                           item.isOutOfStock ? Colors.red : Colors.orange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          copy.dashboardStockLine(item.stockQty, item.unit, item.lowStockThreshold),
                          style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(item.isOutOfStock ? copy.t('outOfStock') : copy.t('lowStock'),
                              item.isOutOfStock ? Colors.red : Colors.orange),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }

  Widget _salesSection(BuildContext context, AppCopy copy, ReportsSnapshot data, List<dynamic> preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(copy.t('recentSales'), copy.t('recentSalesSubtitle')),
        const SizedBox(height: 16),
        if (data.recentSales.isEmpty)
          _emptyCard(context, icon: Icons.sell_outlined, text: copy.t('noSalesYet'))
        else ...[
          ...preview.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _iconBox(Icons.sell_rounded, AppTheme.accentBlue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['product_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          copy.dashboardRecentSaleSubtitle(
                            customerName: row['customer_name']?.toString() ?? '',
                            qty: row['qty'],
                            date: AppFormatters.dateTimeString(row['date']?.toString()),
                          ),
                          style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppFormatters.currency(_toDouble(row['total_sale'])),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.accentBlue),
                  ),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 13)),
      ],
    );
  }

  Widget _quickActionTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceSecondary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.lightBorder,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          else
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: AppTheme.accentBlue, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, AppCopy copy) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceSecondary : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart_rounded, size: 24, color: AppTheme.accentBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('dashboardHero'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.t('professionalDashboard'),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }

  Widget _emptyCard(BuildContext context, {required IconData icon, required String text}) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.textSecondaryFor(context).withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(color: AppTheme.textSecondaryFor(context))),
          ],
        ),
      ),
    );
  }


  Widget _buildSkeleton(BuildContext context, AppCopy copy) {
    return const Center(child: SkeletonLoader());
  }

  Widget _buildErrorState(BuildContext context, AppCopy copy, String? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 16),
          Text(error ?? copy.t('somethingWentWrong')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refresh,
            child: Text(copy.t('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard(BuildContext context, AppCopy copy) {
    final status = _restoreStatusData?['status'] ?? 'unknown';
    final lastDate = _restoreStatusData?['last_restore'];
    
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.cloud_download_rounded, AppTheme.accentBlue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.t('restoreFromCloud'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      status == 'used' ? copy.t('restoreUsed') : copy.t('restoreUnused'),
                      style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!_isRestoring)
                TextButton.icon(
                  onPressed: _restoreFromCloud,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(copy.t('restore')),
                )
              else
                const CircularProgressIndicator(strokeWidth: 2),
            ],
          ),
          if (lastDate != null) ...[
            const SizedBox(height: 12),
            Text(
              copy.dashboardLastRestore(AppFormatters.dateTimeString(lastDate.toString())),
              style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
