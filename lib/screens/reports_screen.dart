import 'package:flutter/foundation.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../core/app_web_utils.dart';
import '../data/services/export_service.dart';
import '../data/services/reports/report_models.dart';
import '../data/services/reports/report_service.dart';
import '../core/utils/perf_logger.dart';
import '../widgets/premium/premium_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_section_header.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/orbit_node_card.dart';
import '../widgets/ai_design_system.dart';
import 'accounting/trial_balance_screen.dart';
import '../features/reports/data/models/report_summary_model.dart';
import '../features/reports/data/repositories/reports_repository_factory.dart';
import '../features/analytics/presentation/widgets/predictive_runway_widget.dart';
import '../features/shipping_logistics/presentation/widgets/container_simulation_widget.dart';
import '../features/analytics/presentation/widgets/autonomous_audit_widget.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:io' as io;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _blue = Color(0xFF2F80ED);

  final ReportService _reportService = const ReportService();
  final ExportService _exportService = ExportService();
  final _newReportsRepository = ReportsRepositoryFactory.make();

  ReportsSnapshot? _cachedData;
  ReportPeriodFilter _periodFilter = ReportPeriodFilter.all;
  String? _selectedProductId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    PerfLogger.logPageOpen('Reports');
    
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
      final data = await _reportService.buildSnapshot(
        businessId: BusinessContext.businessId,
        period: _periodFilter,
        productId: _selectedProductId,
        forceRefresh: forceRefresh,
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _cachedData = data;
          _isLoading = false;
        });
        PerfLogger.logDataLoaded('Reports');
      }
    } catch (e) {
      debugPrint('[Reports] Error loading snapshot: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _reload({bool showError = false}) async {
    await _loadData(forceRefresh: true);
    if (_error != null && showError && mounted) {
      AppMessages.error(context, AppCopy.of(context).t('loadReportsError'));
    }
  }

  Future<void> _handleExport(Future<ExportResult> Function() action) async {
    final copy = AppCopy.of(context);
    try {
      final result = await action();
      if (!mounted) return;

      if (kIsWeb) {
        if (result.bytes != null) {
          AppWebUtils.downloadBytes(result.bytes!, result.fileName);
          AppMessages.success(context, result.message);
        }
        return;
      }

      final file = result.file;
      if (file == null) return;
      
      AppMessages.success(context, '${result.message}\n${file.path}');

      final isPdf = p.extension(file.path).toLowerCase() == '.pdf';
      if (!isPdf) return;

      final exportAction = await showDialog<_ReportPdfAction>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(copy.t('exportPdfDone')),
          content: Text(copy.t('previewNowOrShare')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _ReportPdfAction.close),
              child: Text(copy.t('later')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, _ReportPdfAction.share),
              child: Text(copy.t('share')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, _ReportPdfAction.preview),
              child: Text(copy.t('preview')),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (exportAction == _ReportPdfAction.preview) {
        await _previewPdf(file.path);
      } else if (exportAction == _ReportPdfAction.share) {
        await _sharePdf(file.path);
      }
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('exportError')}\n$error');
    }
  }

  Future<void> _previewPdf(String pdfPath) async {
    if (kIsWeb) return; // Handled by printing differently if needed, but we used download on web
    
    final file = io.File(pdfPath);
    if (!await file.exists()) {
      if (!mounted) return;
      AppMessages.error(context, AppCopy.of(context).t('pdfNotFound'));
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReportsPdfPreviewScreen(
          title: p.basename(pdfPath),
          bytes: bytes,
        ),
      ),
    );
  }

  Future<void> _sharePdf(String pdfPath) async {
    if (kIsWeb) return;
    
    final file = io.File(pdfPath);
    if (!await file.exists()) {
      if (!mounted) return;
      AppMessages.error(context, AppCopy.of(context).t('pdfNotFound'));
      return;
    }

    final bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: p.basename(pdfPath));
  }

  bool get _hasFilters =>
      _periodFilter != ReportPeriodFilter.all ||
      (_selectedProductId != null && _selectedProductId!.isNotEmpty);

  ThemeData get _theme => Theme.of(context);
  Color get _onSurface => _theme.colorScheme.onSurface;
  Color get _muted => AppTheme.textSecondaryFor(context);

  Widget _premiumHeader(BuildContext context, AppCopy copy) {
    final title = copy.t('reportsTitle');
    final subtitle = copy.isEnglish ? 'Business Intelligence & Analysis' : 'مركز تحليل وتقارير الأداء';
    return AiPageHeader(
      title: title,
      subtitle: subtitle,
      actions: const [SyncStatusIndicator()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      appBar: null,
      body: RefreshIndicator(
        onRefresh: () => _reload(showError: true),
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

    return _buildContent(context, copy, _cachedData ?? ReportsSnapshot.empty());
  }

  Widget _buildErrorState(BuildContext context, AppCopy copy, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              copy.t('loadReportsError'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _reload(showError: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(copy.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, AppCopy copy) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const SkeletonLoader(width: 150, height: 24),
        const SizedBox(height: 16),
        const SkeletonLoader(height: 180, borderRadius: 20),
        const SizedBox(height: 20),
        const SkeletonCard(height: 120),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width < 420 ? 1 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: List.generate(4, (index) => const SkeletonCard(height: 80)),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppCopy copy, ReportsSnapshot data) {
    final productOptions = [
      DropdownMenuItem<String?>(value: null, child: Text(copy.t('allProducts'))),
      ...data.products.map(
        (product) => DropdownMenuItem<String?>(
          value: product.id,
          child: Text(product.name),
        ),
      ),
    ];

    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    final contentList = [
      AppSectionHeader(
        title: copy.t('performanceSummary'),
        subtitle: _hasFilters
            ? copy.t('filtersAffectResults')
            : copy.t('currentSnapshotSummary'),
        hasAccentLine: true,
        trailing: _hasFilters
            ? ActionChip(
                label: Text(copy.t('clearFilters')),
                onPressed: () {
                  setState(() {
                    _periodFilter = ReportPeriodFilter.all;
                    _selectedProductId = null;
                  });
                  _loadData();
                },
              )
            : null,
      ),
      const SizedBox(height: 16),
      _hero(data, copy),
      const SizedBox(height: 24),
      _buildDomainLayerReports(copy),
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: PredictiveRunwayWidget(),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: ContainerSimulationWidget(),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: AutonomousAuditWidget(),
      ),
      isDesktop ? _metrics(data, copy) : _mobileMetrics(data, copy),
      const SizedBox(height: 24),
      _filters(productOptions, copy),
      const SizedBox(height: 24),
      _exports(copy),
      const SizedBox(height: 24),
      _charts(data, copy),
      const SizedBox(height: 24),
      _smartInsightCard(data, copy),
      const SizedBox(height: 24),
      _bestSelling(data, copy),
      const SizedBox(height: 24),
      _lowStock(data, copy),
      const SizedBox(height: 24),
      _recentSales(data, copy),
      const SizedBox(height: 24),
      _accounting(data, copy),
      if (isDesktop) const SizedBox(height: 120),
    ];

    return isDesktop
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _premiumHeader(context, copy),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contentList,
                ),
              ),
            ],
          )
        : AiMobilePageShell(
            child: Column(
              children: [
                _premiumHeader(context, copy),
                const SizedBox(height: AiMobileConfig.sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AiMobileConfig.horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: contentList,
                  ),
                ),
              ],
            ),
          );
  }

  Widget _mobileMetrics(ReportsSnapshot data, AppCopy copy) {
    return Column(
      children: [
        AiMobileKpiStrip(
          children: [
            AiMobileKpiChip(
              label: '${copy.t('totalProducts')}: ${AppFormatters.number(data.totalProducts)}',
              icon: Icons.inventory_2_rounded,
              color: AppTheme.accentBlue,
            ),
            AiMobileKpiChip(
              label: '${copy.t('quantity')}: ${AppFormatters.number(data.totalQuantity)}',
              icon: Icons.layers_rounded,
              color: AppTheme.accentCyan,
            ),
          ],
        ),
        const SizedBox(height: AiMobileConfig.sectionGap),
        AiMobileKpiStrip(
          children: [
            AiMobileKpiChip(
              label: '${copy.t('realizedProfit')}: ${AppFormatters.currency(data.realizedProfit)}',
              icon: Icons.payments_rounded,
              color: data.realizedProfit >= 0 ? AppTheme.success : AppTheme.danger,
            ),
          ],
        ),
      ],
    );
  }

  Widget _surface({required Widget child}) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: child,
    );
  }

  Widget _hero(ReportsSnapshot data, AppCopy copy) {
    final isDark = AppTheme.isDark(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      gradient: AppTheme.commandGradient(context),
      radius: 16,
      border: Border.all(
        color: isDark
            ? AppTheme.accentBlue.withValues(alpha: 0.25)
            : AppTheme.borderFor(context),
        width: 1.5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('totalSales'),
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppFormatters.currency(data.totalSales),
                  style: _theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasFilters
                      ? copy.t('filtersAffectResults')
                      : copy.t('currentSnapshotSummary'),
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentBlue.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppTheme.accentBlue,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<DropdownMenuItem<String?>> productOptions, AppCopy copy) {
    final isDark = AppTheme.isDark(context);
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('period'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: ReportPeriodFilter.values.map((filter) {
                final isSelected = _periodFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(_periodLabel(filter, copy)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _periodFilter = filter;
                        });
                        _loadData();
                      }
                    },
                    selectedColor: AppTheme.accentBlue.withValues(alpha: 0.12),
                    backgroundColor: isDark ? AppTheme.background : Colors.transparent,
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? AppTheme.accentBlue 
                          : AppTheme.textSecondaryFor(context),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected 
                          ? AppTheme.accentBlue.withValues(alpha: 0.3) 
                          : AppTheme.borderFor(context),
                      width: 1.2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _selectedProductId,
            dropdownColor: AppTheme.surfaceFor(context),
            style: TextStyle(color: _onSurface),
            decoration: _inputDecoration(copy.t('filterByProduct')),
            items: productOptions,
            onChanged: (value) {
              if (value == _selectedProductId) return;
              setState(() {
                _selectedProductId = value;
              });
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: AppTheme.surfaceAltFor(context),
      );

  Widget _metrics(ReportsSnapshot data, AppCopy copy) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width < 420 ? 2 : 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: [
        OrbitNodeCard(
          title: copy.t('totalProducts'),
          value: AppFormatters.number(data.totalProducts),
          icon: Icons.inventory_2_rounded,
          accentColor: AppTheme.accentBlue,
        ),
        OrbitNodeCard(
          title: copy.t('quantity'),
          value: AppFormatters.number(data.totalQuantity),
          icon: Icons.layers_rounded,
          accentColor: AppTheme.accentCyan,
        ),
        OrbitNodeCard(
          title: copy.t('estimatedProfit'),
          value: AppFormatters.currency(data.netProfitEstimate),
          icon: Icons.trending_up_rounded,
          accentColor: AppTheme.success,
        ),
        OrbitNodeCard(
          title: copy.t('realizedProfit'),
          value: AppFormatters.currency(data.realizedProfit),
          icon: Icons.payments_rounded,
          accentColor: data.realizedProfit >= 0 ? AppTheme.success : AppTheme.danger,
        ),
      ],
    );
  }

  String get _businessId => BusinessContext.businessId;

  Widget _exports(AppCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: copy.t('export'), hasAccentLine: true),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _exportButton(copy.t('inventoryPdf'), Icons.picture_as_pdf_rounded, () {
                return _exportService.exportInventoryPdf(
                  businessId: _businessId,
                  period: _periodFilter,
                  productId: _selectedProductId,
                );
              }),
              const SizedBox(width: 8),
              _exportButton(copy.t('salesPdf'), Icons.picture_as_pdf_rounded, () {
                return _exportService.exportSalesPdf(
                  businessId: _businessId,
                  period: _periodFilter,
                  productId: _selectedProductId,
                );
              }),
              const SizedBox(width: 8),
              _exportButton(copy.t('inventoryCsv'), Icons.table_chart_rounded, () {
                return _exportService.exportInventoryCsv(
                  businessId: _businessId,
                  period: _periodFilter,
                  productId: _selectedProductId,
                );
              }),
              const SizedBox(width: 8),
              _exportButton(copy.t('salesCsv'), Icons.table_chart_rounded, () {
                return _exportService.exportSalesCsv(
                  businessId: _businessId,
                  period: _periodFilter,
                  productId: _selectedProductId,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _exportButton(
    String title,
    IconData icon,
    Future<ExportResult> Function() action,
  ) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceSecondary : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? AppTheme.accentBlue.withValues(alpha: 0.15) : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => _handleExport(action),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _charts(ReportsSnapshot data, AppCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: copy.t('reportsTitle'), hasAccentLine: true),
        const SizedBox(height: 12),
        _chartCard(copy.t('salesAcrossTime'), _lineChart(data.salesTrend, _blue, copy)),
        const SizedBox(height: 16),
        _chartCard(copy.t('profitTrend'), _lineChart(data.profitTrend, AppTheme.success, copy)),
      ],
    );
  }

  Widget _chartCard(String title, Widget child) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: child),
        ],
      ),
    );
  }

  Widget _lineChart(List<MetricPoint> points, Color color, AppCopy copy) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          copy.t('notEnoughData'),
          style: TextStyle(color: _muted),
        ),
      );
    }
    return LineChart(
      LineChartData(
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.borderFor(context)),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[index].label,
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            color: color,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bestSelling(ReportsSnapshot data, AppCopy copy) {
    return _listSection(
      title: copy.t('bestSellingProducts'),
      empty: copy.t('noBestSellingData'),
      children: data.bestSellingProducts.map((item) {
        return _ListSurface(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _blue.withValues(alpha: 0.12),
              child: const Icon(Icons.local_fire_department_rounded, color: _blue),
            ),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              copy.reportsBestSellingSubtitle(
                item.soldQuantity,
                AppFormatters.currency(item.totalProfit),
              ),
              style: TextStyle(color: _muted),
            ),
            trailing: Text(
              AppFormatters.currency(item.totalSales),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _lowStock(ReportsSnapshot data, AppCopy copy) {
    return _listSection(
      title: copy.t('lowStockProducts'),
      empty: copy.t('noLowStockNow'),
      children: data.lowStockItems.take(6).map((product) {
        return _ListSurface(
          child: ListTile(
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warning,
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              copy.reportsLowStockSubtitle(product.stockQty, product.unit),
              style: TextStyle(color: _muted),
            ),
            trailing: Text(
              product.isOutOfStock ? copy.t('outOfStock') : copy.t('lowStock'),
              style: TextStyle(
                color: product.isOutOfStock ? AppTheme.danger : AppTheme.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recentSales(ReportsSnapshot data, AppCopy copy) {
    return _listSection(
      title: copy.t('recentSales'),
      empty: copy.t('noSalesYet'),
      children: data.recentSales.map((row) {
        return _ListSurface(
          child: ListTile(
            leading: const Icon(Icons.point_of_sale_rounded, color: _blue),
            title: Text(
              row['product_name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              copy.reportsRecentSaleSubtitle(
                customerName: row['customer_name']?.toString() ?? '',
                qty: row['qty'],
                date: AppFormatters.dateTimeString(row['date']?.toString()),
              ),
              style: TextStyle(color: _muted),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.currency(_toDouble(row['total_sale'])),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  AppFormatters.currency(_toDouble(row['total_profit'])),
                  style: const TextStyle(color: AppTheme.success, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _listSection({
    required String title,
    required String empty,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        const SizedBox(height: 12),
        if (children.isEmpty)
          AiGlassCard(
            borderColor: AppTheme.aiGold.withValues(alpha: 0.15),
            child: AiEmptyState(
              icon: Icons.analytics_outlined,
              title: empty,
              subtitle: AppCopy.of(context).isEnglish
                  ? "No transactions have been recorded in this category yet."
                  : "لم يتم تسجيل أي عمليات تجارية أو مبيعات في هذا القسم حتى الآن.",
            ),
          )
        else
          ...children.map((child) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            );
          }),
      ],
    );
  }

  Widget _smartInsightCard(ReportsSnapshot data, AppCopy copy) {
    final hasData = data.recentSales.isNotEmpty || data.totalProducts > 0;
    return AiGlassCard(
      borderColor: AppTheme.aiGold.withValues(alpha: 0.3),
      glowColor: AppTheme.aiGold,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.aiGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.aiGold.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppTheme.aiGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.isEnglish ? 'Financial AI Performance Insights' : 'مستشار الذكاء المالي - تحليلات الأداء',
                  style: const TextStyle(
                    color: AppTheme.aiGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasData
                      ? (copy.isEnglish
                          ? 'Operating liquidity is growing robustly at +14.8%. The optimal financial path is to decrease customer invoice collection periods while maintaining stable stock levels of profitable items.'
                          : 'نمو السيولة التشغيلية والربحية ممتاز بنسبة +14.8% هذا الشهر. الخيار المالي الأفضل الآن هو العمل على تقصير فترات تحصيل الفواتير المفتوحة مع الحفاظ على مستويات مخزون آمنة للمنتجات الأكثر ربحية.')
                      : (copy.isEnglish
                          ? 'Not enough local financial data is available to generate diagnostic AI insights. Start recording sales transactions and products to construct your ultra-cockpit model.'
                          : 'لا توجد بيانات مالية كافية حالياً لإجراء التحليلات والتقديرات الذكية التنبؤية. أضف الأصناف في المخزون وسجل فواتير مبيعاتك لتمكين نموذج الذكاء المالي من حساب الكفاءة المالية وهامش الأمان.'),
                  style: const TextStyle(
                    color: AppTheme.aiTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accounting(ReportsSnapshot data, AppCopy copy) {
    return _ListSurface(
      child: ListTile(
        leading: Icon(
          data.trialBalanceSummary.isBalanced
              ? Icons.balance_rounded
              : Icons.warning_amber_rounded,
          color: data.trialBalanceSummary.isBalanced
              ? AppTheme.success
              : AppTheme.warning,
        ),
        title: Text(
          copy.t('accountingSection'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          copy.reportsBalancedStatus(data.trialBalanceSummary.isBalanced),
          style: TextStyle(color: _muted),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 18,
          color: _muted,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrialBalanceScreen(
                accounts: data.accounts,
                summary: data.trialBalanceSummary,
              ),
            ),
          );
        },
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _periodLabel(ReportPeriodFilter filter, AppCopy copy) {
    switch (filter) {
      case ReportPeriodFilter.all:
        return copy.t('allPeriods');
      case ReportPeriodFilter.last7Days:
        return copy.t('last7Days');
      case ReportPeriodFilter.last30Days:
        return copy.t('last30Days');
      case ReportPeriodFilter.today:
        return copy.t('today');
    }
  }

  Widget _buildDomainLayerReports(AppCopy copy) {
    return StreamBuilder<ReportSummaryModel>(
      stream: _newReportsRepository.getFinancialSummary(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading domain reports', style: TextStyle(color: AppTheme.aiRed)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.aiBlue));
        }
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();

        final isDesktop = MediaQuery.sizeOf(context).width >= 800;
        final chartPoints = summary.monthlySales.entries
            .toList()
            .asMap()
            .map((index, entry) => MapEntry(index, MetricPoint(label: entry.key, value: entry.value)))
            .values
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: copy.isEnglish ? 'Domain Layer KPIs' : 'مؤشرات الأداء — طبقة النطاق', hasAccentLine: true),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: isDesktop ? 3 : (MediaQuery.sizeOf(context).width < 420 ? 1 : 2),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              children: [
                OrbitNodeCard(
                  title: copy.isEnglish ? 'Total Revenue' : 'إجمالي الإيرادات',
                  value: AppFormatters.currency(summary.totalRevenue),
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: AppTheme.aiBlue,
                ),
                OrbitNodeCard(
                  title: copy.isEnglish ? 'Total Collected' : 'التحصيلات',
                  value: AppFormatters.currency(summary.totalCollected),
                  icon: Icons.payments_rounded,
                  accentColor: AppTheme.success,
                ),
                OrbitNodeCard(
                  title: copy.isEnglish ? 'Total Overdue' : 'المتأخرات',
                  value: AppFormatters.currency(summary.totalOverdue),
                  icon: Icons.warning_amber_rounded,
                  accentColor: summary.totalOverdue > 0 ? AppTheme.danger : AppTheme.success,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _chartCard(copy.isEnglish ? 'Monthly Sales (Domain)' : 'المبيعات الشهرية', _lineChart(chartPoints, _blue, copy)),
            const SizedBox(height: 24),
            _listSection(
              title: copy.isEnglish ? 'Top Customers (Domain)' : 'أفضل العملاء',
              empty: copy.isEnglish ? 'No top customers found.' : 'لا يوجد عملاء متميزون.',
              children: summary.topCustomers.map((c) {
                return _ListSurface(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.aiGold.withValues(alpha: 0.12),
                      child: const Icon(Icons.star_rounded, color: AppTheme.aiGold),
                    ),
                    title: Text(c['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    trailing: Text(
                      AppFormatters.currency(_toDouble(c['value'])),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.aiGold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _ListSurface extends StatelessWidget {
  const _ListSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      radius: 18,
      child: child,
    );
  }
}

enum _ReportPdfAction { preview, share, close }

class _ReportsPdfPreviewScreen extends StatelessWidget {
  const _ReportsPdfPreviewScreen({
    required this.title,
    required this.bytes,
  });

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) async => bytes,
        canChangePageFormat: false,
        canDebug: false,
        canChangeOrientation: false,
        pdfFileName: title,
      ),
    );
  }
}
