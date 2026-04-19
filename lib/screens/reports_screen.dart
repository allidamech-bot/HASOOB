import 'dart:io';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/services/export_service.dart';
import '../data/services/reports/report_models.dart';
import '../data/services/reports/report_service.dart';
import '../widgets/app_section_header.dart';
import '../widgets/metric_card.dart';
import 'accounting/trial_balance_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _blue = Color(0xFF2F80ED);

  final ReportService _reportService = const ReportService();
  final ExportService _exportService = ExportService();

  late Future<ReportsSnapshot> _snapshot;
  ReportPeriodFilter _periodFilter = ReportPeriodFilter.all;
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _snapshot = _buildSnapshot();
  }

  Future<ReportsSnapshot> _buildSnapshot() {
    return _reportService.buildSnapshot(
      period: _periodFilter,
      productId: _selectedProductId,
    );
  }

  Future<void> _reload({bool showError = false}) async {
    final future = _buildSnapshot();
    if (mounted) {
      setState(() => _snapshot = future);
    }
    try {
      await future;
    } catch (error) {
      if (!mounted || !showError) return;
      AppMessages.error(context, '${AppCopy.of(context).t('loadReportsError')}\n$error');
    }
  }

  Future<void> _handleExport(Future<ExportResult> Function() action) async {
    final copy = AppCopy.of(context);
    try {
      final result = await action();
      if (!mounted) return;
      AppMessages.success(context, '${result.message}\n${result.file.path}');

      final isPdf = p.extension(result.file.path).toLowerCase() == '.pdf';
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
        await _previewPdf(result.file.path);
      } else if (exportAction == _ReportPdfAction.share) {
        await _sharePdf(result.file.path);
      }
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('exportError')}\n$error');
    }
  }

  Future<void> _previewPdf(String pdfPath) async {
    final file = File(pdfPath);
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
    final file = File(pdfPath);
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

  BoxDecoration get _surfaceDecoration => BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow(context),
      );

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          copy.t('reportsTitle'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _reload(showError: true),
        child: FutureBuilder<ReportsSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
                        const SizedBox(height: 12),
                        Text(
                          copy.t('loadReportsError'),
                          style: _theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('${snapshot.error}', style: TextStyle(color: _muted)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _reload(),
                          child: Text(copy.t('retry')),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _surface(
                    child: Text(
                      copy.t('noDataAvailable'),
                      style: _theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              );
            }

            final productOptions = [
              DropdownMenuItem<String?>(value: null, child: Text(copy.t('allProducts'))),
              ...data.products.map(
                (product) => DropdownMenuItem<String?>(
                  value: product.id,
                  child: Text(product.name),
                ),
              ),
            ];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                AppSectionHeader(
                  title: copy.t('performanceSummary'),
                  subtitle: _hasFilters
                      ? copy.t('filtersAffectResults')
                      : copy.t('currentSnapshotSummary'),
                  trailing: _hasFilters
                      ? ActionChip(
                          label: Text(copy.t('clearFilters')),
                          onPressed: () {
                            setState(() {
                              _periodFilter = ReportPeriodFilter.all;
                              _selectedProductId = null;
                              _snapshot = _buildSnapshot();
                            });
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                _hero(data, copy),
                const SizedBox(height: 20),
                _filters(productOptions, copy),
                const SizedBox(height: 20),
                _metrics(data, copy),
                const SizedBox(height: 20),
                _exports(copy),
                const SizedBox(height: 20),
                _charts(data, copy),
                const SizedBox(height: 20),
                _bestSelling(data, copy),
                const SizedBox(height: 20),
                _lowStock(data, copy),
                const SizedBox(height: 20),
                _recentSales(data, copy),
                const SizedBox(height: 20),
                _accounting(data, copy),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _surface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration,
      child: child,
    );
  }

  Widget _hero(ReportsSnapshot data, AppCopy copy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceAltFor(context),
            AppTheme.surfaceFor(context),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded, color: _blue),
          ),
          const SizedBox(height: 16),
          Text(
            copy.t('totalSales'),
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            AppFormatters.currency(data.totalSales),
            style: _theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasFilters
                ? copy.t('filtersAffectResults')
                : copy.t('currentSnapshotSummary'),
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<DropdownMenuItem<String?>> productOptions, AppCopy copy) {
    return _surface(
      child: Column(
        children: [
          DropdownButtonFormField<ReportPeriodFilter>(
            value: _periodFilter,
            dropdownColor: AppTheme.surfaceFor(context),
            style: TextStyle(color: _onSurface),
            decoration: _inputDecoration(copy.t('period')),
            items: ReportPeriodFilter.values
                .map(
                  (filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(_periodLabel(filter, copy)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null || value == _periodFilter) return;
              setState(() {
                _periodFilter = value;
                _snapshot = _buildSnapshot();
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _selectedProductId,
            dropdownColor: AppTheme.surfaceFor(context),
            style: TextStyle(color: _onSurface),
            decoration: _inputDecoration(copy.t('filterByProduct')),
            items: productOptions,
            onChanged: (value) {
              if (value == _selectedProductId) return;
              setState(() {
                _selectedProductId = value;
                _snapshot = _buildSnapshot();
              });
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _muted),
        filled: true,
        fillColor: AppTheme.surfaceAltFor(context),
      );

  Widget _metrics(ReportsSnapshot data, AppCopy copy) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width < 420 ? 1 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        MetricCard(
          title: copy.t('totalProducts'),
          value: AppFormatters.number(data.totalProducts),
          icon: Icons.inventory_2_rounded,
        ),
        MetricCard(
          title: copy.t('quantity'),
          value: AppFormatters.number(data.totalQuantity),
          icon: Icons.layers_rounded,
        ),
        MetricCard(
          title: copy.t('estimatedProfit'),
          value: AppFormatters.currency(data.netProfitEstimate),
          icon: Icons.trending_up_rounded,
          accentColor: AppTheme.success,
        ),
        MetricCard(
          title: copy.t('realizedProfit'),
          value: AppFormatters.currency(data.realizedProfit),
          icon: Icons.payments_rounded,
          accentColor:
              data.realizedProfit >= 0 ? AppTheme.success : AppTheme.danger,
        ),
      ],
    );
  }

  Widget _exports(AppCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: copy.t('export')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _exportButton(copy.t('inventoryPdf'), Icons.picture_as_pdf_rounded, () {
              return _exportService.exportInventoryPdf(
                period: _periodFilter,
                productId: _selectedProductId,
              );
            }),
            _exportButton(copy.t('salesPdf'), Icons.picture_as_pdf_rounded, () {
              return _exportService.exportSalesPdf(
                period: _periodFilter,
                productId: _selectedProductId,
              );
            }),
            _exportButton(copy.t('inventoryCsv'), Icons.table_chart_rounded, () {
              return _exportService.exportInventoryCsv(
                period: _periodFilter,
                productId: _selectedProductId,
              );
            }),
            _exportButton(copy.t('salesCsv'), Icons.table_chart_rounded, () {
              return _exportService.exportSalesCsv(
                period: _periodFilter,
                productId: _selectedProductId,
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _exportButton(
    String title,
    IconData icon,
    Future<ExportResult> Function() action,
  ) {
    return FilledButton.icon(
      onPressed: () => _handleExport(action),
      icon: Icon(icon),
      label: Text(title),
    );
  }

  Widget _charts(ReportsSnapshot data, AppCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: copy.t('reportsTitle')),
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
          SizedBox(height: 240, child: child),
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
          _surface(child: Text(empty, style: _theme.textTheme.titleMedium))
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
}

class _ListSurface extends StatelessWidget {
  const _ListSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
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
