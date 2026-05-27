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
import 'package:hasoob_app/screens/add_product_screen.dart';
import 'package:hasoob_app/screens/business_profile_screen.dart';
import 'package:hasoob_app/screens/customers_screen.dart';
import 'package:hasoob_app/screens/documents_screen.dart';
import 'package:hasoob_app/screens/settings_screen.dart';
import 'package:hasoob_app/widgets/premium/premium_card.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/widgets/sync_status_indicator.dart';
import 'package:hasoob_app/widgets/sync_health_card.dart';
import 'package:hasoob_app/widgets/local_mode_status_card.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hasoob_app/widgets/business_health_module.dart';
import 'package:hasoob_app/widgets/orbit_node_card.dart';
import 'package:hasoob_app/widgets/app_section_header.dart';
import 'package:hasoob_app/widgets/ai_design_system.dart';
import 'package:hasoob_app/widgets/ai_robot_advisor.dart';

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

  Widget _actionCapsule(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final isDark = AppTheme.isDark(context);
    final color = accentColor ?? AppTheme.accentBlue;

    return Tooltip(
      message: tooltip,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceSecondary : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isDark ? color.withValues(alpha: 0.15) : AppTheme.lightBorder,
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            onTap: onTap,
            child: Icon(
              icon,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _premiumHeader(BuildContext context, AppCopy copy) {
    final isDark = AppTheme.isDark(context);
    final now = DateTime.now();
    final monthsAr = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"];
    final monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final dateStr = copy.isEnglish 
        ? "${now.day} ${monthsEn[now.month - 1]} ${now.year}"
        : "${now.day} ${monthsAr[now.month - 1]} ${now.year}";

    final greeting = copy.isEnglish ? "Welcome, Ahmed" : "مرحباً، أحمد";
    final subtitle = copy.isEnglish ? "SaaS Business Command Center" : "مركز قيادة الأعمال الذكي";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDeep : AppTheme.lightBackgroundDeep,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXLarge),
          bottomRight: Radius.circular(AppTheme.radiusXLarge),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "•",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action capsules
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SyncStatusIndicator(),
                    const SizedBox(width: 8),
                    _actionCapsule(
                      context,
                      icon: Icons.apartment_rounded,
                      tooltip: copy.t('businessProfile'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionCapsule(
                      context,
                      icon: Icons.settings_outlined,
                      tooltip: copy.t('settings'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionCapsule(
                      context,
                      icon: Icons.logout_rounded,
                      tooltip: copy.t('logout'),
                      onTap: () => AuthService.instance.signOut(),
                      accentColor: AppTheme.danger,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: null, // Premium custom header used instead
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        displacement: 100,
        child: _buildBody(context, copy),
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

    return _buildContent(context, copy);
  }

  Widget _buildContent(BuildContext context, AppCopy copy) {
    final data = _cachedData ?? ReportsSnapshot.empty();
    final lowStockPreview = data.lowStockItems.take(3).toList();
    final recentSalesPreview = data.recentSales.take(3).toList();
    final isWide = MediaQuery.sizeOf(context).width >= 1000;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return CustomScrollView(
      slivers: [
        // Top Toolbar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SyncStatusIndicator(),
                const SizedBox(width: 8),
                _actionCapsule(
                  context,
                  icon: Icons.apartment_rounded,
                  tooltip: copy.t('businessProfile'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                  ),
                  accentColor: AppTheme.aiBlue,
                ),
                const SizedBox(width: 8),
                _actionCapsule(
                  context,
                  icon: Icons.settings_outlined,
                  tooltip: copy.t('settings'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  accentColor: AppTheme.aiBlue,
                ),
                const SizedBox(width: 8),
                _actionCapsule(
                  context,
                  icon: Icons.logout_rounded,
                  tooltip: copy.t('logout'),
                  onTap: () => AuthService.instance.signOut(),
                  accentColor: AppTheme.aiRed,
                ),
              ],
            ),
          ),
        ),
        // AI Hero
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AiRobotAdvisor(
              greeting: copy.isEnglish ? "What is the best financial decision today?" : "ما القرار المالي الأفضل اليوم؟",
              advisorTitle: copy.isEnglish ? "FINANCIAL ADVISOR ACTIVE" : "المستشار المالي نشط",
              suggestion: copy.isEnglish ? "Analyzing cash flow, obligations, inventory, and sales..." : "يتم تحليل التدفق النقدي، الالتزامات، المخزون، والمبيعات...",
            ),
          ),
        ),
        // KPIs Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : (isDesktop ? 2 : 2),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 1.8 : 2.0,
            ),
            delegate: SliverChildListDelegate([
              OrbitNodeCard(
                title: copy.t('totalProducts'),
                value: AppFormatters.number(data.totalProducts),
                icon: Icons.inventory_2_rounded,
                accentColor: AppTheme.aiBlue,
              ),
              OrbitNodeCard(
                title: copy.t('totalSales'),
                value: AppFormatters.currency(data.totalSales),
                icon: Icons.point_of_sale_rounded,
                accentColor: AppTheme.aiGold,
              ),
              OrbitNodeCard(
                title: copy.t('estimatedProfit'),
                value: AppFormatters.currency(data.netProfitEstimate),
                icon: Icons.trending_up_rounded,
                accentColor: AppTheme.aiGreen,
              ),
              OrbitNodeCard(
                title: copy.t('lowStockCount'),
                value: AppFormatters.number(data.lowStockItems.length),
                icon: Icons.warning_amber_rounded,
                accentColor: AppTheme.aiRed,
                trendText: data.lowStockItems.isEmpty ? null : "${data.lowStockItems.length}",
                isTrendUp: false,
              ),
            ]),
          ),
        ),
        // Additional Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (Firebase.apps.isEmpty) ...[
                  const LocalModeStatusCard(),
                  const SizedBox(height: 16),
                ],
                const SyncHealthCard(),
                const SizedBox(height: 24),
                const SizedBox(height: 28),
                AppSectionHeader(
                  title: copy.t('quickActions'),
                  hasAccentLine: true,
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
                
                const SizedBox(height: 28),
                _buildRestoreCard(context, copy),
                
                const SizedBox(height: 28),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? AppTheme.accentBlue.withValues(alpha: 0.15) : AppTheme.lightBorder,
          width: 1.2,
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(icon, color: AppTheme.accentBlue, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
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

  Widget _emptyCard(BuildContext context, {required IconData icon, required String text, Widget? action}) {
    return AiEmptyState(
      icon: icon,
      title: text,
      subtitle: AppCopy.of(context).isEnglish 
          ? "Data will appear here once available" 
          : "ستظهر البيانات هنا فور توفرها",
      action: action,
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
    final isDark = AppTheme.isDark(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceSecondary : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.borderFor(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 16,
            color: AppTheme.accentBlue.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status == 'used' ? copy.t('restoreUsed') : copy.t('restoreUnused'),
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (lastDate != null) ...[
            Text(
              copy.dashboardLastRestore(AppFormatters.dateTimeString(lastDate.toString())),
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (!_isRestoring)
            InkWell(
              onTap: _restoreFromCloud,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  copy.t('restore'),
                  style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
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
