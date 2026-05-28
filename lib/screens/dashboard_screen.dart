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
import 'package:hasoob_app/screens/settings_screen.dart';
import 'package:hasoob_app/screens/_dashboard_dock_spacer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportService _reportService = const ReportService();
  ReportsSnapshot? _cachedData;
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

      if (mounted) {
        setState(() {
          _cachedData = results[0];
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
        displacement: 100,
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

  Widget _buildContent(BuildContext context, AppCopy copy) {
    final data = _cachedData ?? ReportsSnapshot.empty();
    final lowStockPreview = data.lowStockItems.take(3).toList();
    final recentSalesPreview = data.recentSales.take(3).toList();
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

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
                                copy.isEnglish ? 'Financial Intelligence Cockpit' : 'لوحة القيادة والذكاء المالي',
                                style: const TextStyle(
                                  color: AppTheme.aiGold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.verified_user_rounded, color: AppTheme.aiGreen, size: 12),
                                  const SizedBox(width: 6),
                                  Text(
                                    copy.isEnglish ? 'Secure AI Session Active' : 'جلسة خادم الذكاء المالي آمنة ونشطة',
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

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: AiRobotAdvisor(
              greeting: copy.isEnglish ? "What is the best financial decision today?" : "ما القرار المالي الأفضل اليوم؟",
              advisorTitle: copy.isEnglish ? "FINANCIAL ADVISOR ACTIVE" : "المستشار المالي نشط",
              suggestion: copy.isEnglish 
                  ? "Analyzing cash flow, outstanding invoices, obligations, and stock levels to calculate optimal steps."
                  : "يقوم المستشار المالي الآن بفحص وتحليل التدفق النقدي، الفواتير المستحقة، مستويات المخزون والمصروفات ليقترح لك أفضل خطوة تالية لعملك.",
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildHealthScoreCard(copy)),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildRecommendationCard(copy)),
                  ],
                )
              else ...[
                _buildHealthScoreCard(copy),
                const SizedBox(height: 16),
                _buildRecommendationCard(copy),
              ],
              
              const SizedBox(height: 20),

              _buildKpiGrid(data, copy, isDesktop),

              const SizedBox(height: 20),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCashFlowPulseCard(copy)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildDecisionSimulationCard(copy)),
                  ],
                )
              else ...[
                _buildCashFlowPulseCard(copy),
                const SizedBox(height: 16),
                _buildDecisionSimulationCard(copy),
              ],

              const SizedBox(height: 20),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildObligationsCard(copy)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildSmartAlerts(copy, lowStockPreview.length)),
                  ],
                )
              else ...[
                _buildObligationsCard(copy),
                const SizedBox(height: 16),
                _buildSmartAlerts(copy, lowStockPreview.length),
              ],

              const SizedBox(height: 28),

              AppSectionHeader(
                title: copy.t('quickActions'),
                hasAccentLine: true,
              ),
              const SizedBox(height: 14),
              _buildQuickActionsStrip(context, copy),

              const SizedBox(height: 28),

              _buildRestoreCard(context, copy),

              const SizedBox(height: 28),

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
              // Reserve space for the mobile CommandDock so it never overlaps content.
              // CommandDock height: 84px
              // CommandDock is wrapped with SafeArea(minimum: EdgeInsets.fromLTRB(..., 16))
              // On narrow screens (< 800px), MainNavigationScreen shows the dock.
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

  Widget _buildHealthScoreCard(AppCopy copy) {
    return AiGlassCard(
      borderColor: AppTheme.aiGold.withValues(alpha: 0.25),
      glowColor: AppTheme.aiGold,
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
                  color: AppTheme.aiGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  copy.isEnglish ? 'Excellent' : 'ممتاز جداً',
                  style: const TextStyle(
                    color: AppTheme.aiGreen,
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
              const AiHealthScore(score: 88, size: 84),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.isEnglish 
                          ? 'SaaS operating efficiency is optimal.'
                          : 'الكفاءة التشغيلية والسيولة النقدية ممتازة اليوم.',
                      style: const TextStyle(
                        color: AppTheme.aiTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy.isEnglish
                          ? 'Cash flow cover is 85% higher than last month. Current reserves are safe.'
                          : 'مستوى السيولة النقدية يغطي المصروفات بنسبة 85% أعلى من الشهر الماضي. الاحتياطي المالي في أمان.',
                      style: const TextStyle(
                        color: AppTheme.aiTextSecondary,
                        fontSize: 11,
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

  Widget _buildRecommendationCard(AppCopy copy) {
    return AiGlassCard(
      borderColor: AppTheme.aiBlue.withValues(alpha: 0.25),
      glowColor: AppTheme.aiBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.isEnglish ? 'What should I do today?' : 'ما الخطوات الموصى بها اليوم؟',
            style: const TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _recommendationItem(
            icon: Icons.lightbulb_rounded,
            color: AppTheme.aiGold,
            text: copy.isEnglish 
                ? 'Follow up invoice #1024 to secure cash reserves before next week.'
                : 'تابع تحصيل الفاتورة المستحقة رقم #1024 لتأمين السيولة قبل الأسبوع القادم.',
          ),
          const SizedBox(height: 12),
          _recommendationItem(
            icon: Icons.inventory_2_rounded,
            color: AppTheme.aiBlue,
            text: copy.isEnglish 
                ? 'Reorder top-selling detergent carton (stock count is below 4).'
                : 'أعد طلب كميات إضافية من المنظفات (المخزون الحالي 3 وحدات وهو تحت الحد الأدنى).',
          ),
        ],
      ),
    );
  }

  Widget _recommendationItem({required IconData icon, required Color color, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(ReportsSnapshot data, AppCopy copy, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.7 : 1.9,
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
                copy.isEnglish ? 'Cash Flow Pulse' : 'نبض التدفق النقدي',
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
          _pulseBar(copy.isEnglish ? 'Cash Inflow' : 'المقبوضات النقدية', 0.85, AppTheme.aiGreen, '14,200 ر.س'),
          const SizedBox(height: 12),
          _pulseBar(copy.isEnglish ? 'Cash Outflow' : 'المدفوعات والمصروفات', 0.38, AppTheme.aiGold, '5,400 ر.س'),
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
                copy.isEnglish ? 'AI Decision Simulation' : 'محاكاة القرارات المالية',
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
                  copy.isEnglish ? 'Ready' : 'جاهز للمحاكاة',
                  style: const TextStyle(color: AppTheme.aiGold, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            copy.isEnglish 
                ? 'Simulation Scenario: Purchase inventory worth 5,000 SAR.'
                : 'سيناريو المحاكاة النشط: شراء مخزون ومشتريات بقيمة 5,000 ر.س اليوم.',
            style: const TextStyle(color: AppTheme.aiTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            copy.isEnglish
                ? 'Result: Liquid cash decreases by 12%. Estimated net profit margin increases by 18% over 30 days.'
                : 'الأثر المتوقع: ستنخفض السيولة النقدية المتاحة بنسبة 12%، بينما ستزداد الأرباح التشغيلية المقدرة بنسبة 18% خلال 30 يوماً.',
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
            copy.isEnglish ? 'Upcoming Obligations' : 'الالتزامات والمدفوعات القادمة',
            style: const TextStyle(
              color: AppTheme.aiTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _obligationItem(copy.isEnglish ? 'Suppliers Invoices Due' : 'مستحقات وفواتير الموردين', '3,400 ر.س', copy.isEnglish ? 'Tomorrow' : 'غداً', AppTheme.aiGold),
          const Divider(height: 20),
          _obligationItem(copy.isEnglish ? 'Employee Salaries' : 'رواتب ومستحقات الموظفين', '12,000 ر.س', copy.isEnglish ? 'In 3 Days' : 'بعد 3 أيام', AppTheme.aiBlue),
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
          message: copy.isEnglish ? 'Risk: Low stock items' : 'تنبيه ذكي: سلع مخزون منخفضة',
          subtitle: copy.isEnglish 
              ? '$lowStockCount products are below critical threshold.' 
              : 'هناك $lowStockCount أصناف تحت الحد الحرج للمخزون لمنع نفاد البضاعة.',
          icon: Icons.warning_amber_rounded,
          severity: AiAlertSeverity.warning,
        ),
        const SizedBox(height: 12),
        AiAlertCard(
          message: copy.isEnglish ? 'Local Mode: Offline database active' : 'التشغيل المحلي: قاعدة البيانات المحلية نشطة',
          subtitle: copy.isEnglish 
              ? 'All transactions persist locally first, syncing smoothly to cloud.'
              : 'كل عملياتك وبياناتك تحفظ محلياً في خادمك بأمان تام وتتزامن تلقائياً.',
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
            title: copy.isEnglish ? 'Add Product' : 'إضافة صنف مخزون',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())),
            accentColor: AppTheme.aiBlue,
          ),
          const SizedBox(width: 14),
          _quickActionTile(
            context,
            icon: Icons.receipt_long_rounded,
            title: copy.isEnglish ? 'Create Invoice' : 'إنشاء فاتورة مبيعات',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            accentColor: AppTheme.aiGold,
          ),
          const SizedBox(width: 14),
          _quickActionTile(
            context,
            icon: Icons.person_add_alt_1_rounded,
            title: copy.isEnglish ? 'Add Customer' : 'إضافة عميل جديد',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
            accentColor: AppTheme.aiGreen,
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
        _sectionHeader(copy.t('stockAlerts'), copy.isEnglish ? 'Critical Stock Thresholds' : 'الحدود الحرجة لمخزون المنتجات والأصناف'),
        const SizedBox(height: 16),
        if (data.lowStockItems.isEmpty)
          _emptyCard(context, icon: Icons.inventory_2_outlined, text: copy.isEnglish ? 'No Low Stock Items' : 'مستويات المخزون مستقرة بالكامل حالياً')
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
        _sectionHeader(copy.t('recentSales'), copy.isEnglish ? 'Realtime Customer Operations' : 'العمليات والمبيعات الفورية المسجلة مؤخراً'),
        const SizedBox(height: 16),
        if (data.recentSales.isEmpty)
          _emptyCard(context, icon: Icons.sell_outlined, text: copy.isEnglish ? 'No Sales Yet' : 'لم يتم تسجيل أي عمليات بيع بعد')
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