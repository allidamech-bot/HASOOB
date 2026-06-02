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
import 'package:hasoob_app/widgets/premium/premium_card.dart';
import 'package:hasoob_app/data/services/sync_manager.dart';
import 'package:hasoob_app/widgets/sync_status_indicator.dart';
import 'package:hasoob_app/widgets/app_section_header.dart';
import 'package:hasoob_app/widgets/ai_design_system.dart';
import 'package:hasoob_app/widgets/ai_robot_advisor.dart';
import 'package:hasoob_app/screens/add_product_screen.dart';
import 'package:hasoob_app/screens/business_profile_screen.dart';
import 'package:hasoob_app/screens/customers_screen.dart';
import 'package:hasoob_app/screens/documents_screen.dart';
import 'package:hasoob_app/screens/collection_center_screen.dart';
import 'package:hasoob_app/screens/settings_screen.dart';
import 'package:hasoob_app/screens/_dashboard_dock_spacer.dart';
import 'package:hasoob_app/core/business/daily_decision_engine.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportService _reportService = const ReportService();
  ReportsSnapshot? _cachedData;
  List<BusinessDecision>? _decisions;
  bool _isRestoring = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    PerfLogger.logPageOpen('Dashboard');
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
      final results = await Future.wait([
        _reportService.buildSnapshot(businessId: businessId, forceRefresh: forceRefresh)
            .timeout(const Duration(seconds: 10)),
      ]);

      final snapshot = results[0];
      final decisions = await DailyDecisionEngine.instance.generateDecisions(businessId, snapshot);

      if (mounted) {
        setState(() {
          _cachedData = snapshot;
          _decisions = decisions;
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
      backgroundColor: AppTheme.aiDeep,
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
                ? AppTheme.aiCardElevated
                : AppTheme.aiGold,
            elevation: 8,
            icon: manager.isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.black),
            label: Text(
              manager.isRunning ? copy.t('syncRunning') : copy.t('syncNow'),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        displacement: 40,
        backgroundColor: AppTheme.aiCard,
        color: AppTheme.aiGold,
        child: _buildBody(context, copy),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppCopy copy) {
    if (_isLoading && _cachedData == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.aiGold));
    }
    
    if (_error != null && _cachedData == null) {
      return _buildErrorState(context, copy, _error);
    }

    return _buildContent(context, copy);
  }

  Widget _buildMobileHeader(BuildContext context, AppCopy copy) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiNavy,
        border: const Border(bottom: BorderSide(color: AppTheme.aiCardBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AiMobileConfig.horizontalPadding, 12, AiMobileConfig.horizontalPadding, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppTheme.aiGold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    copy.isEnglish ? 'Hasoob' : 'حاسوب',
                    style: AiMobileConfig.pageTitle.copyWith(color: AppTheme.aiGold),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SyncStatusIndicator(),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    child: const Icon(Icons.settings_outlined, color: AppTheme.aiTextSecondary, size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileQuickActions(BuildContext context, AppCopy copy) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
      child: Row(
        children: [
          AiMobileActionCard(
            title: copy.t('dashboardAddProduct'),
            icon: Icons.add_box_rounded,
            color: AppTheme.aiBlue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
          ),
          const SizedBox(width: 12),
          AiMobileActionCard(
            title: copy.t('dashboardCreateInvoice'),
            icon: Icons.receipt_long_rounded,
            color: AppTheme.aiGold,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
          ),
          const SizedBox(width: 12),
          AiMobileActionCard(
            title: copy.t('dashboardAddCustomer'),
            icon: Icons.person_add_alt_1_rounded,
            color: AppTheme.aiGreen,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
          ),
          const SizedBox(width: 12),
          AiMobileActionCard(
            title: copy.isEnglish ? 'Collection Center' : 'مركز التحصيل',
            icon: Icons.account_balance_wallet_rounded,
            color: AppTheme.aiRed,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionCenterScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppCopy copy) {
    final data = _cachedData ?? ReportsSnapshot.empty();
    final lowStockPreview = data.lowStockItems.take(3).toList();
    final recentSalesPreview = data.recentSales.take(3).toList();
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    if (!isDesktop) {
      return AiMobilePageShell(
        child: Column(
          children: [
            _buildMobileHeader(context, copy),
            const SizedBox(height: AiMobileConfig.sectionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
              child: _buildDecisionCommander(_decisions ?? [], copy),
            ),
            const SizedBox(height: AiMobileConfig.sectionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
              child: _buildMobileFinancialHealthAndKPIs(data, copy),
            ),
            const SizedBox(height: AiMobileConfig.sectionGap),
            AiMobileSectionHeader(title: copy.t('quickActions')),
            const SizedBox(height: 12),
            _buildMobileQuickActions(context, copy),
            const SizedBox(height: AiMobileConfig.sectionGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
              child: Column(
                children: [
                  _buildCashFlowPulseCard(copy),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  _buildDecisionSimulationCard(copy),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  _buildObligationsCard(copy),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  _buildSmartAlerts(copy, lowStockPreview.length),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  _stockSection(context, copy, data, lowStockPreview),
                  const SizedBox(height: AiMobileConfig.sectionGap),
                  _salesSection(context, copy, data, recentSalesPreview),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Premium Header with Actions
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.aiNavy,
              border: const Border(
                bottom: BorderSide(color: AppTheme.aiCardBorder, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gold accent bar
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, AppTheme.aiGold, Colors.transparent],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                copy.isEnglish ? 'Hasoob' : 'حاسوب',
                                style: const TextStyle(
                                  color: AppTheme.aiGold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.verified_user_rounded, color: AppTheme.aiGreen, size: 12),
                                  const SizedBox(width: 6),
                                  Text(
                                    copy.t('dashboardSecureSession'),
                                    style: const TextStyle(
                                      color: AppTheme.aiTextSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SyncStatusIndicator(),
                            const SizedBox(width: 10),
                            _actionCapsule(
                              context,
                              icon: Icons.apartment_rounded,
                              tooltip: copy.t('businessProfile'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _actionCapsule(
                              context,
                              icon: Icons.settings_outlined,
                              tooltip: copy.t('settings'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _actionCapsule(
                              context,
                              icon: Icons.logout_rounded,
                              tooltip: copy.t('logout'),
                              onTap: () => AuthService.instance.signOut(),
                              accentColor: AppTheme.aiRed,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (isDesktop)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: AiRobotAdvisor(
                greeting: copy.t('dashboardAiGreeting'),
                advisorTitle: copy.t('dashboardAiTitle'),
                suggestion: copy.t('dashboardAiSuggestion'),
              ),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildHealthScoreCard(data, copy)),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: _buildDecisionCommander(_decisions ?? [], copy)),
                ],
              ),

              const SizedBox(height: 14),
              _buildKpiGrid(data, copy, true),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCashFlowPulseCard(copy)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDecisionSimulationCard(copy)),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildObligationsCard(copy)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSmartAlerts(copy, lowStockPreview.length)),
                ],
              ),

              const SizedBox(height: 20),
              AppSectionHeader(
                title: copy.t('quickActions'),
                hasAccentLine: true,
              ),
              const SizedBox(height: 10),
              _buildQuickActionsStrip(context, copy),

              const SizedBox(height: 20),
              _buildRestoreCard(context, copy),

              const SizedBox(height: 20),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _stockSection(context, copy, data, lowStockPreview)),
                    const SizedBox(width: 24),
                    Expanded(child: _salesSection(context, copy, data, recentSalesPreview)),
                  ],
                )
              else ...[
                _stockSection(context, copy, data, lowStockPreview),
                const SizedBox(height: 28),
                _salesSection(context, copy, data, recentSalesPreview),
              ],

              const SizedBox(height: 120),
              if (!isDesktop)
                SizedBox(height: DashboardDockSpacer.bottomReservedSpace(context)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _actionCapsule(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.aiGold;

    return Tooltip(
      message: tooltip,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppTheme.aiCardElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(ReportsSnapshot? data, AppCopy copy) {
    int score = 0;
    String scoreLabel = copy.isEnglish ? 'Awaiting Data' : 'بانتظار البيانات';
    Color scoreColor = AppTheme.aiTextSecondary;
    String desc1 = copy.isEnglish ? 'Not enough data.' : 'لا توجد بيانات كافية لقياس كفاءة التشغيل حالياً.';
    String desc2 = copy.isEnglish ? 'Add items to start.' : 'ابدأ بإضافة منتجاتك ومبيعاتك الأولى لتفعيل مؤشر الصحة.';

    if (data != null && (data.totalProducts > 0 || data.salesRecords.isNotEmpty)) {
      score = 85;
      scoreLabel = copy.isEnglish ? 'Excellent' : 'ممتاز جداً';
      scoreColor = AppTheme.aiGreen;

      if (data.lowStockItems.length > 5) {
        score = 65;
        scoreLabel = copy.isEnglish ? 'Needs Attention' : 'يحتاج انتباه';
        scoreColor = AppTheme.aiGold;
      }

      desc1 = copy.isEnglish 
          ? 'You have ${data.totalProducts} active products.' 
          : 'الكفاءة التشغيلية ممتازة، لديك ${data.totalProducts} صنف نشط.';
      desc2 = copy.isEnglish
          ? 'Total sales recorded is ${data.totalSales.toStringAsFixed(2)}.'
          : 'إجمالي المبيعات يبلغ ${data.totalSales.toStringAsFixed(2)} ر.س، السيولة مستقرة وآمنة.';
    }

    return AiGlassCard(
      borderColor: scoreColor.withValues(alpha: 0.25),
      glowColor: scoreColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                copy.isEnglish ? 'Financial Health Score' : 'مؤشر الصحة المالية',
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  scoreLabel,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              AiHealthScore(score: score.toDouble(), size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc1,
                      style: const TextStyle(
                        color: AppTheme.aiTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc2,
                      style: const TextStyle(
                        color: AppTheme.aiTextSecondary,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFinancialHealthAndKPIs(ReportsSnapshot data, AppCopy copy) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: PremiumCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monitor_heart_rounded, color: AppTheme.aiGreen, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      copy.isEnglish ? 'Health' : 'الصحة',
                      style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'مستقرة',
                  style: TextStyle(color: AppTheme.aiGreen, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'أداء جيد',
                  style: TextStyle(color: AppTheme.aiTextMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildCompactKpiRow(Icons.account_balance_wallet_rounded, AppTheme.aiGold, copy.isEnglish ? 'Sales' : 'المبيعات', AppFormatters.currency(data.totalSales)),
              const SizedBox(height: 8),
              _buildCompactKpiRow(Icons.inventory_2_rounded, AppTheme.aiBlue, copy.isEnglish ? 'Stock' : 'المخزون', AppFormatters.currency(data.totalStockValue)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactKpiRow(IconData icon, Color color, String label, String value) {
    return PremiumCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 12),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 11))),
          Text(value, style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDecisionCommander(List<BusinessDecision> decisions, AppCopy copy) {
    return AiGlassCard(
      borderColor: AppTheme.aiGold.withValues(alpha: 0.4),
      glowColor: AppTheme.aiGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.aiGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: AppTheme.aiGold, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'ماذا أفعل اليوم؟',
                style: TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (decisions.isEmpty || decisions.any((d) => d.priority == DecisionPriority.info && d.title == 'إعداد بيانات النشاط التجاري'))
            _buildEmptyDecisionState(copy)
          else
            ...decisions.map((d) => _decisionItem(d)),
        ],
      ),
    );
  }

  Widget _buildEmptyDecisionState(AppCopy copy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.aiCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, color: AppTheme.aiTextSecondary, size: 48),
          const SizedBox(height: 16),
          const Text(
            'لا توجد بيانات كافية لإصدار قرارات مالية دقيقة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.aiTextPrimary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'أضف بياناتك الأولى ليقوم الذكاء المالي بتحليلها واقتراح أفضل الخطوات لك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.aiTextSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _setupActionButton('إضافة منتج', Icons.inventory_2_outlined, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
              }),
              _setupActionButton('إنشاء فاتورة', Icons.receipt_long_outlined, () {}),
              _setupActionButton('إضافة عميل', Icons.person_add_outlined, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setupActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.aiBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.aiBlue.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.aiBlue, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppTheme.aiBlue, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _decisionItem(BusinessDecision decision) {
    Color color;
    IconData icon;
    switch (decision.priority) {
      case DecisionPriority.critical:
        color = AppTheme.aiRed;
        icon = Icons.error_outline_rounded;
        break;
      case DecisionPriority.warning:
        color = AppTheme.aiGold;
        icon = Icons.warning_amber_rounded;
        break;
      case DecisionPriority.opportunity:
        color = AppTheme.aiGreen;
        icon = Icons.trending_up_rounded;
        break;
      case DecisionPriority.info:
        color = AppTheme.aiBlue;
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    decision.title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.aiDeep,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radar, color: color, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${(decision.confidenceScore * 100).toInt()}% دقة',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            decision.explanation,
            style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.aiCardElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.data_usage_rounded, color: AppTheme.aiTextSecondary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    decision.sourceDataSummary,
                    style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                if (decision.navigationTarget != null) {
                  if (decision.navigationTarget == 'collection') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionCenterScreen()));
                  } else if (decision.navigationTarget == 'invoices') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()));
                  } else if (decision.navigationTarget == 'products' || decision.navigationTarget == 'inventory') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
                  }
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  decision.suggestedActionLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(ReportsSnapshot data, AppCopy copy, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.7 : 2.2,
          children: [
            AiKpiCard(
              label: copy.t('totalProducts'),
              value: AppFormatters.number(data.totalProducts),
              icon: Icons.inventory_2_rounded,
              accentColor: AppTheme.aiBlue,
            ),
            AiKpiCard(
              label: copy.t('totalSales'),
              value: AppFormatters.currency(data.totalSales),
              icon: Icons.point_of_sale_rounded,
              accentColor: AppTheme.aiGold,
              trendText: "+14.8%",
              isTrendUp: true,
            ),
            AiKpiCard(
              label: copy.t('estimatedProfit'),
              value: AppFormatters.currency(data.netProfitEstimate),
              icon: Icons.trending_up_rounded,
              accentColor: AppTheme.aiGreen,
              trendText: "+8.2%",
              isTrendUp: true,
            ),
            AiKpiCard(
              label: copy.t('lowStockCount'),
              value: AppFormatters.number(data.lowStockItems.length),
              icon: Icons.warning_amber_rounded,
              accentColor: AppTheme.aiRed,
              trendText: data.lowStockItems.isEmpty ? null : "${data.lowStockItems.length}",
              isTrendUp: false,
            ),
          ],
        );
      }
    );
  }

  Widget _buildCashFlowPulseCard(AppCopy copy) {
    return AiGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                copy.t('dashboardCashFlowPulse'),
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Icon(Icons.analytics_rounded, color: AppTheme.aiBlue, size: 18),
            ],
          ),
          const SizedBox(height: 20),
          _pulseBar(copy.t('dashboardCashInflow'), 0.85, AppTheme.aiGreen, '14,200 ر.س'),
          const SizedBox(height: 12),
          _pulseBar(copy.t('dashboardCashOutflow'), 0.38, AppTheme.aiGold, '5,400 ر.س'),
        ],
      ),
    );
  }

  Widget _pulseBar(String label, double percentage, Color color, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(amount, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionSimulationCard(AppCopy copy) {
    return AiGlassCard(
      borderColor: AppTheme.aiGold.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                copy.t('dashboardAiSimulation'),
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.aiGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  copy.t('dashboardSimulationReady'),
                  style: const TextStyle(color: AppTheme.aiGold, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            copy.t('dashboardSimulationScenario'),
            style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            copy.t('dashboardSimulationResult'),
            style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildObligationsCard(AppCopy copy) {
    return AiGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('dashboardObligations'),
            style: const TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _obligationItem(copy.t('dashboardObligation1'), '3,400 ر.س', copy.t('dashboardTomorrow'), AppTheme.aiGold),
          const Divider(height: 20),
          _obligationItem(copy.t('dashboardObligation2'), '12,000 ر.س', copy.t('dashboardIn3Days'), AppTheme.aiBlue),
        ],
      ),
    );
  }

  Widget _obligationItem(String title, String amount, String date, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(amount, style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildSmartAlerts(AppCopy copy, int lowStockCount) {
    return Column(
      children: [
        AiAlertCard(
          message: copy.t('dashboardAlertLowStock'),
          subtitle: copy.dashboardLowStockAlertSubtitle(lowStockCount),
          icon: Icons.warning_amber_rounded,
          severity: AiAlertSeverity.warning,
        ),
        const SizedBox(height: 12),
        AiAlertCard(
          message: copy.t('dashboardAlertLocalMode'),
          subtitle: copy.dashboardLocalModeSubtitle(),
          icon: Icons.cloud_done_rounded,
          severity: AiAlertSeverity.success,
        ),
      ],
    );
  }

  Widget _buildQuickActionsStrip(BuildContext context, AppCopy copy) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _quickActionTile(
            context,
            icon: Icons.add_box_rounded,
            title: copy.t('dashboardAddProduct'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
            accentColor: AppTheme.aiBlue,
          ),
          const SizedBox(width: 14),
          _quickActionTile(
            context,
            icon: Icons.receipt_long_rounded,
            title: copy.t('dashboardCreateInvoice'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            accentColor: AppTheme.aiGold,
          ),
          const SizedBox(width: 14),
          _quickActionTile(
            context,
            icon: Icons.person_add_alt_1_rounded,
            title: copy.t('dashboardAddCustomer'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
            accentColor: AppTheme.aiGreen,
          ),
          const SizedBox(width: 14),
          _quickActionTile(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: copy.isEnglish ? 'Collection Center' : 'مركز التحصيل',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionCenterScreen())),
            accentColor: AppTheme.aiRed,
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.aiCardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockSection(BuildContext context, AppCopy copy, ReportsSnapshot data, List<dynamic> preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(copy.t('stockAlerts'), copy.t('dashboardStockThresholds')),
        const SizedBox(height: 16),
        if (data.lowStockItems.isEmpty)
          _emptyCard(context, icon: Icons.inventory_2_outlined, text: copy.t('dashboardNoLowStock'))
        else ...[
          ...preview.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _iconBox(item.isOutOfStock ? Icons.remove_shopping_cart_rounded : Icons.warning_amber_rounded, 
                           item.isOutOfStock ? AppTheme.aiRed : AppTheme.aiGold),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          copy.dashboardStockLine(item.stockQty, item.unit, item.lowStockThreshold),
                          style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(item.isOutOfStock ? copy.t('outOfStock') : copy.t('lowStock'),
                              item.isOutOfStock ? AppTheme.aiRed : AppTheme.aiGold),
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
        _sectionHeader(copy.t('recentSales'), copy.t('dashboardRecentOperations')),
        const SizedBox(height: 16),
        if (data.recentSales.isEmpty)
          _emptyCard(context, icon: Icons.sell_outlined, text: copy.t('dashboardNoSalesYet'))
        else ...[
          ...preview.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _iconBox(Icons.sell_rounded, AppTheme.aiGold),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['product_name']?.toString() ?? '', style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          copy.dashboardRecentSaleSubtitle(
                            customerName: row['customer_name']?.toString() ?? '',
                            qty: row['qty'],
                            date: AppFormatters.dateTimeString(row['date']?.toString()),
                          ),
                          style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppFormatters.currency(_toDouble(row['total_sale'])),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.aiGold),
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
        Text(title, style: const TextStyle(color: AppTheme.aiTextPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: AppTheme.aiTextSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
  }

  Widget _emptyCard(BuildContext context, {required IconData icon, required String text}) {
    return AiEmptyState(
      icon: icon,
      title: text,
      subtitle: AppCopy.of(context).isEnglish 
          ? "No business records available for this section." 
          : "لا توجد سجلات تجارية متوفرة في هذا القسم حالياً.",
    );
  }

  Widget _buildErrorState(BuildContext context, AppCopy copy, String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.aiRed),
            const SizedBox(height: 16),
            Text(
              error ?? copy.t('somethingWentWrong'),
              style: const TextStyle(color: AppTheme.aiTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.aiGold, foregroundColor: Colors.black),
              child: Text(copy.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreCard(BuildContext context, AppCopy copy) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_download_outlined,
            size: 20,
            color: AppTheme.aiGold,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('restoreFromCloud'),
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  copy.t('restoreFromCloudSubtitle'),
                  style: const TextStyle(
                    color: AppTheme.aiTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!_isRestoring)
            InkWell(
              onTap: _restoreFromCloud,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  copy.t('restore'),
                  style: const TextStyle(
                    color: AppTheme.aiBlue,
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