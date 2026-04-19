import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/app_formatters.dart';
import '../models/product.dart';
import 'reports/report_models.dart';
import 'reports/report_service.dart';

enum ExportReportType {
  inventory,
  salesHistory,
  generalSummary,
  trialBalance,
}

class ExportResult {
  const ExportResult({
    required this.file,
    required this.message,
  });

  final File file;
  final String message;
}

class ExportService {
  ExportService({ReportService? reportService})
      : _reportService = reportService ?? const ReportService();

  final ReportService _reportService;

  static const PdfColor _pdfBg = PdfColor.fromInt(0xFF0B1020);
  static const PdfColor _pdfPanel = PdfColor.fromInt(0xFF131A2E);
  static const PdfColor _pdfPanelAlt = PdfColor.fromInt(0xFF1A223A);
  static const PdfColor _pdfAccent = PdfColor.fromInt(0xFFD4AF37);
  static const PdfColor _pdfBorder = PdfColor.fromInt(0xFF2C3654);
  static const PdfColor _pdfSoftText = PdfColor.fromInt(0xFFB8C2D9);
  static const PdfColor _pdfMuted = PdfColor.fromInt(0xFF8E9AB8);
  static const PdfColor _pdfWhite = PdfColors.white;
  static const PdfColor _pdfSuccess = PdfColor.fromInt(0xFF28C76F);
  static const PdfColor _pdfWarning = PdfColor.fromInt(0xFFFF9F43);
  static const PdfColor _pdfDanger = PdfColor.fromInt(0xFFEA5455);

  String _profileText(Map<String, dynamic>? businessProfile, String key) {
    return _cleanText(businessProfile?[key]?.toString());
  }

  String _businessDisplayName(Map<String, dynamic>? businessProfile) {
    final businessName = _profileText(businessProfile, 'business_name');
    if (businessName.isNotEmpty) return businessName;
    return _profileText(businessProfile, 'trade_name');
  }

  List<List<String>> _businessIdentityRows(
      Map<String, dynamic>? businessProfile,
      ) {
    final rows = <List<String>>[];

    void addRow(String label, String key) {
      final value = _profileText(businessProfile, key);
      if (value.isNotEmpty) {
        rows.add([label, value]);
      }
    }

    addRow('الهاتف', 'phone');
    addRow('واتساب', 'whatsapp');
    addRow('البريد الإلكتروني', 'email');
    addRow('العنوان', 'address');
    addRow('الرقم الضريبي', 'tax_number');
    addRow('السجل التجاري', 'registration_number');

    return rows;
  }

  String _cleanText(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('\u200B', '')
        .replaceAll('\u2060', '')
        .replaceAll('\uFEFF', '')
        .trim();
  }

  List<String> _cleanRow(List<dynamic> row) {
    return row.map((item) => _cleanText(item?.toString())).toList();
  }

  Future<ExportResult> exportInventoryCsv({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final products = productId == null || productId.isEmpty
        ? snapshot.products
        : snapshot.products.where((item) => item.id == productId).toList();

    final lines = <String>[
      'id,name,unit,purchase_price,extra_costs,selling_price,stock_qty,low_stock_threshold,barcode,unit_profit,total_stock_value',
      ...products.map(
            (item) => [
          _escape(item.id),
          _escape(item.name),
          _escape(item.unit),
          _escape(item.purchasePrice),
          _escape(item.extraCosts),
          _escape(item.sellingPrice),
          _escape(item.stockQty),
          _escape(item.lowStockThreshold),
          _escape(item.barcode ?? ''),
          _escape(item.netProfit),
          _escape(item.totalStockValue),
        ].join(','),
      ),
    ];

    return _writeTextFile(
      prefix: 'inventory_report',
      extension: 'csv',
      content: lines.join('\n'),
      successMessage: 'تم حفظ تقرير المخزون بصيغة CSV بنجاح.',
    );
  }

  Future<ExportResult> exportSalesCsv({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final sales = snapshot.salesRecords;

    final lines = <String>[
      'product_id,product_name,customer_name,sale_note,qty,currency_code,selling_price,landed_cost,total_sale,total_profit,date',
      ...sales.map(
            (row) => [
          _escape(row['product_id']),
          _escape(row['product_name']),
          _escape(row['customer_name']),
          _escape(row['sale_note']),
          _escape(row['qty']),
          _escape(row['currency_code']),
          _escape(row['selling_price']),
          _escape(row['landed_cost']),
          _escape(row['total_sale']),
          _escape(row['total_profit']),
          _escape(row['date']),
        ].join(','),
      ),
    ];

    return _writeTextFile(
      prefix: 'sales_history',
      extension: 'csv',
      content: lines.join('\n'),
      successMessage: 'تم حفظ سجل المبيعات بصيغة CSV بنجاح.',
    );
  }

  Future<ExportResult> exportSummaryCsv({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final selectedProductName = _selectedProductLabel(
      snapshot.products,
      productId,
    );

    final lines = <String>[
      'metric,value',
      'إجمالي الأصناف,${snapshot.totalProducts}',
      'إجمالي الكمية,${snapshot.totalQuantity}',
      'قيمة المخزون,${snapshot.totalStockValue}',
      'إجمالي المبيعات,${snapshot.totalSales}',
      'صافي الربح المتوقع,${snapshot.netProfitEstimate}',
      'الربح المحقق,${snapshot.realizedProfit}',
      'الأصناف منخفضة المخزون,${snapshot.lowStockItems.length}',
      'الفترة,${_periodLabel(period)}',
      'تصفية الصنف,$selectedProductName',
    ];

    return _writeTextFile(
      prefix: 'general_summary',
      extension: 'csv',
      content: lines.join('\n'),
      successMessage: 'تم حفظ الملخص العام بصيغة CSV بنجاح.',
    );
  }

  Future<ExportResult> exportInventoryPdf({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final products = productId == null || productId.isEmpty
        ? snapshot.products
        : snapshot.products.where((item) => item.id == productId).toList();

    return _writePdfFile(
      prefix: 'inventory_report',
      type: ExportReportType.inventory,
      summary: [
        ['نوع التقرير', 'تقرير المخزون'],
        ['الفترة', _periodLabel(period)],
        [
          'تصفية الصنف',
          productId == null || productId.isEmpty
              ? 'كل الأصناف'
              : _productName(products, productId),
        ],
      ],
      tableHeaders: const [
        'الصنف',
        'الوحدة',
        'الكمية',
        'الحد الأدنى',
        'سعر البيع',
        'قيمة المخزون',
      ],
      tableRows: products
          .map(
            (item) => [
          item.name,
          item.unit,
          '${item.stockQty}',
          '${item.lowStockThreshold}',
          AppFormatters.currency(item.sellingPrice),
          AppFormatters.currency(item.totalStockValue),
        ],
      )
          .toList(),
      title: 'تقرير المخزون',
      subtitle: 'يعرض هذا التقرير حالة المخزون الحالية وقيمته التقديرية.',
      successMessage: 'تم إنشاء ملف PDF لتقرير المخزون بنجاح.',
    );
  }

  Future<ExportResult> exportSalesPdf({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final sales = snapshot.salesRecords;
    final selectedProductName = _selectedProductLabel(
      snapshot.products,
      productId,
    );

    return _writePdfFile(
      prefix: 'sales_history',
      type: ExportReportType.salesHistory,
      summary: [
        ['نوع التقرير', 'سجل المبيعات'],
        ['الفترة', _periodLabel(period)],
        ['تصفية الصنف', selectedProductName],
        ['عدد العمليات', '${sales.length}'],
        [
          'إجمالي المبيعات',
          AppFormatters.currency(
            sales.fold<double>(
              0,
                  (sum, row) => sum + _toDouble(row['total_sale']),
            ),
          ),
        ],
      ],
      tableHeaders: const [
        'التاريخ',
        'الصنف',
        'العملة',
        'العميل',
        'الكمية',
        'سعر الوحدة الأصلي',
        'إجمالي البيع الأصلي',
        'إجمالي البيع المحاسبي',
      ],
      tableRows: sales
          .map(
            (row) => [
          AppFormatters.dateTimeString(row['date']?.toString()),
          row['product_name']?.toString() ?? '',
          row['currency_code']?.toString() ?? '',
          row['customer_name']?.toString() ?? '-',
          '${row['qty'] ?? 0}',
          AppFormatters.currencyWithCode(
            _toDouble(row['selling_price']),
            row['currency_code']?.toString(),
          ),
          AppFormatters.currencyWithCode(
            _toDouble(row['total_sale']),
            row['currency_code']?.toString(),
          ),
          AppFormatters.currencyWithCode(
            _toDouble(row['total_sale']),
            row['currency_code']?.toString(),
          ),
        ],
      )
          .toList(),
      title: 'تقرير سجل المبيعات',
      subtitle: 'ملخص احترافي للمبيعات المنفذة والأرباح المحققة.',
      successMessage: 'تم إنشاء ملف PDF لسجل المبيعات بنجاح.',
    );
  }

  Future<ExportResult> exportSummaryPdf({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final selectedProductName = _selectedProductLabel(
      snapshot.products,
      productId,
    );

    return _writePdfFile(
      prefix: 'general_summary',
      type: ExportReportType.generalSummary,
      summary: [
        ['الفترة', _periodLabel(period)],
        ['تصفية الصنف', selectedProductName],
        ['إجمالي الأصناف', '${snapshot.totalProducts}'],
        ['إجمالي الكمية', '${snapshot.totalQuantity}'],
        ['قيمة المخزون', AppFormatters.currency(snapshot.totalStockValue)],
        ['إجمالي المبيعات', AppFormatters.currency(snapshot.totalSales)],
        [
          'صافي الربح المتوقع',
          AppFormatters.currency(snapshot.netProfitEstimate),
        ],
        ['الربح المحقق', AppFormatters.currency(snapshot.realizedProfit)],
      ],
      tableHeaders: const ['المؤشر', 'القيمة'],
      tableRows: [
        [
          'أفضل الأصناف مبيعاً',
          snapshot.bestSellingProducts.isEmpty
              ? '-'
              : snapshot.bestSellingProducts.map((e) => e.name).join('، '),
        ],
        ['أصناف منخفضة المخزون', '${snapshot.lowStockItems.length}'],
        ['عدد القيود اليومية', '${snapshot.journalEntries.length}'],
        [
          'حالة الميزان',
          snapshot.trialBalanceSummary.isBalanced ? 'متوازن' : 'غير متوازن',
        ],
      ],
      title: 'التقرير العام',
      subtitle: 'ملخص تنفيذي للمخزون والمبيعات والأداء المالي.',
      successMessage: 'تم إنشاء ملف PDF للملخص العام بنجاح.',
    );
  }

  Future<ExportResult> exportTrialBalancePdf({
    ReportPeriodFilter period = ReportPeriodFilter.all,
    String? productId,
  }) async {
    final snapshot = await _reportService.buildSnapshot(
      period: period,
      productId: productId,
    );
    final selectedProductName = _selectedProductLabel(
      snapshot.products,
      productId,
    );

    return _writePdfFile(
      prefix: 'trial_balance',
      type: ExportReportType.trialBalance,
      summary: [
        ['الفترة', _periodLabel(period)],
        ['تصفية الصنف', selectedProductName],
        [
          'إجمالي المدين',
          AppFormatters.currency(snapshot.trialBalanceSummary.totalDebit),
        ],
        [
          'إجمالي الدائن',
          AppFormatters.currency(snapshot.trialBalanceSummary.totalCredit),
        ],
        ['عدد القيود', '${snapshot.trialBalanceSummary.entriesCount}'],
        [
          'الحالة',
          snapshot.trialBalanceSummary.isBalanced
              ? 'الميزان متوازن'
              : 'الميزان غير متوازن',
        ],
      ],
      tableHeaders: const ['الكود', 'الحساب', 'النوع', 'مدين', 'دائن'],
      tableRows: snapshot.accounts.map((account) {
        final balance = _toDouble(account['balance']);
        return [
          account['code']?.toString() ?? '',
          account['name']?.toString() ?? '',
          account['category']?.toString() ?? '',
          balance >= 0 ? AppFormatters.currency(balance) : '-',
          balance < 0 ? AppFormatters.currency(balance.abs()) : '-',
        ];
      }).toList(),
      title: 'تقرير ميزان المراجعة',
      subtitle: 'يعرض أرصدة الحسابات مع إجمالي المدين والدائن.',
      successMessage: 'تم إنشاء ملف PDF لميزان المراجعة بنجاح.',
    );
  }

  Future<String> generateInvoicePdf({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? businessProfile,
  }) async {
    final fonts = await _loadPdfFonts();
    final document = pw.Document();

    final logo = await _loadBusinessLogo(
      businessProfile?['logo_path']?.toString(),
    );

    final businessName = _businessDisplayName(businessProfile);
    final businessIdentityRows = _businessIdentityRows(businessProfile);
    final invoiceNumber = _cleanText(invoice['invoice_number']?.toString());
    final customerName = _cleanText(invoice['customer_name']?.toString());
    final issueDate = _cleanText(
      AppFormatters.dateTimeString(invoice['issue_date']?.toString()),
    );
    final dueDate = _cleanText(
      AppFormatters.dateTimeString(invoice['due_date']?.toString()),
    );
    final notes = _cleanText(invoice['notes']?.toString());
    final paymentTermsFooter = _profileText(
      businessProfile,
      'payment_terms_footer',
    );
    final currencyCode = invoice['currency_code']?.toString();
    final total = AppFormatters.currency(
      _toDouble(invoice['total']),
      currencyLabel: currencyCode,
    );
    final paid = AppFormatters.currency(
      _toDouble(invoice['paid_amount']),
      currencyLabel: currencyCode,
    );
    final remaining = AppFormatters.currency(
      _toDouble(invoice['remaining_amount']),
      currencyLabel: currencyCode,
    );
    final status = _invoiceStatusLabel(invoice['status']?.toString());

    document.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(fonts),
        build: (context) => [
          _documentShell(
            fonts: fonts,
            title: 'فاتورة',
            subtitle: invoiceNumber.isEmpty ? 'مستند مالي' : invoiceNumber,
            logo: logo,
            businessName: businessName,
            businessIdentityRows: businessIdentityRows,
            metaRows: [
              ['العميل', customerName.isEmpty ? 'بدون عميل' : customerName],
              ['تاريخ الإصدار', issueDate.isEmpty ? '-' : issueDate],
              ['تاريخ الاستحقاق', dueDate.isEmpty ? '-' : dueDate],
              ['الحالة', status],
            ],
            summaryCards: [
              _SummaryCardData(
                label: 'الإجمالي',
                value: total,
                color: _pdfAccent,
              ),
              _SummaryCardData(
                label: 'المدفوع',
                value: paid,
                color: _pdfSuccess,
              ),
              _SummaryCardData(
                label: 'المتبقي',
                value: remaining,
                color: _toDouble(invoice['remaining_amount']) > 0
                    ? _pdfWarning
                    : _pdfSuccess,
              ),
            ],
            tableHeaders: const [
              'الصنف',
              'الكمية',
              'سعر الوحدة',
              'الإجمالي',
            ],
            tableRows: items.isEmpty
                ? [
              ['لا توجد بنود', '-', '-', '-'],
            ]
                : items
                .map(
                  (item) => [
                _cleanText(item['product_name']?.toString()),
                _cleanText(item['quantity']?.toString()),
                AppFormatters.currency(
                  _toDouble(item['unit_price']),
                  currencyLabel: currencyCode,
                ),
                AppFormatters.currency(
                  _toDouble(item['line_total']),
                  currencyLabel: currencyCode,
                ),
              ],
            )
                .toList(),
            notesTitle: 'ملاحظات الفاتورة',
            notes: notes,
            footerText: paymentTermsFooter,
          ),
        ],
      ),
    );

    final file = await _createFile(
      'invoice_${invoiceNumber.isEmpty ? 'document' : invoiceNumber}',
      'pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file.path;
  }

  Future<String> generateQuotationPdf({
    required Map<String, dynamic> quotation,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? businessProfile,
  }) async {
    final fonts = await _loadPdfFonts();
    final document = pw.Document();

    final logo = await _loadBusinessLogo(
      businessProfile?['logo_path']?.toString(),
    );

    final businessName = _businessDisplayName(businessProfile);
    final businessIdentityRows = _businessIdentityRows(businessProfile);
    final quotationNumber = _cleanText(
      quotation['quotation_number']?.toString(),
    );
    final customerName = _cleanText(quotation['customer_name']?.toString());
    final issueDate = _cleanText(
      AppFormatters.dateTimeString(quotation['issue_date']?.toString()),
    );
    final expiryDate = _cleanText(
      AppFormatters.dateTimeString(quotation['expiry_date']?.toString()),
    );
    final notes = _cleanText(quotation['notes']?.toString());
    final paymentTermsFooter = _profileText(
      businessProfile,
      'payment_terms_footer',
    );
    final currencyCode = quotation['currency_code']?.toString();
    final total = AppFormatters.currency(
      _toDouble(quotation['total']),
      currencyLabel: currencyCode,
    );
    final status = _quotationStatusLabel(quotation['status']?.toString());

    document.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(fonts),
        build: (context) => [
          _documentShell(
            fonts: fonts,
            title: 'عرض سعر',
            subtitle: quotationNumber.isEmpty ? 'مستند عرض' : quotationNumber,
            logo: logo,
            businessName: businessName,
            businessIdentityRows: businessIdentityRows,
            metaRows: [
              ['العميل', customerName.isEmpty ? 'بدون عميل' : customerName],
              ['تاريخ الإصدار', issueDate.isEmpty ? '-' : issueDate],
              ['تاريخ الانتهاء', expiryDate.isEmpty ? '-' : expiryDate],
              ['الحالة', status],
            ],
            summaryCards: [
              _SummaryCardData(
                label: 'الإجمالي',
                value: total,
                color: _pdfAccent,
              ),
            ],
            tableHeaders: const [
              'الصنف',
              'الكمية',
              'سعر الوحدة',
              'الإجمالي',
            ],
            tableRows: items.isEmpty
                ? [
              ['لا توجد بنود', '-', '-', '-'],
            ]
                : items
                .map(
                  (item) => [
                _cleanText(item['product_name']?.toString()),
                _cleanText(item['quantity']?.toString()),
                AppFormatters.currency(
                  _toDouble(item['unit_price']),
                  currencyLabel: currencyCode,
                ),
                AppFormatters.currency(
                  _toDouble(item['line_total']),
                  currencyLabel: currencyCode,
                ),
              ],
            )
                .toList(),
            notesTitle: 'ملاحظات العرض',
            notes: notes,
            footerText: paymentTermsFooter,
          ),
        ],
      ),
    );

    final file = await _createFile(
      'quotation_${quotationNumber.isEmpty ? 'document' : quotationNumber}',
      'pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file.path;
  }

  Future<ExportResult> _writeTextFile({
    required String prefix,
    required String extension,
    required String content,
    required String successMessage,
  }) async {
    final file = await _createFile(prefix, extension);
    await file.writeAsString(content, flush: true);
    return ExportResult(file: file, message: successMessage);
  }

  Future<ExportResult> _writePdfFile({
    required String prefix,
    required ExportReportType type,
    required List<List<String>> summary,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    required String title,
    required String subtitle,
    required String successMessage,
  }) async {
    final fonts = await _loadPdfFonts();
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(fonts),
        build: (context) => [
          _reportShell(
            fonts: fonts,
            type: type,
            title: title,
            subtitle: subtitle,
            summary: summary,
            tableHeaders: tableHeaders,
            tableRows: tableRows,
          ),
        ],
      ),
    );

    final file = await _createFile(prefix, 'pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return ExportResult(file: file, message: successMessage);
  }

  pw.Widget _reportShell({
    required _PdfFonts fonts,
    required ExportReportType type,
    required String title,
    required String subtitle,
    required List<List<String>> summary,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _reportHeader(
          fonts: fonts,
          title: title,
          subtitle: subtitle,
          iconText: _reportIcon(type),
        ),
        pw.SizedBox(height: 18),
        _summaryGrid(
          fonts: fonts,
          rows: summary,
        ),
        pw.SizedBox(height: 18),
        _panel(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تفاصيل التقرير',
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 14,
                  color: _pdfWhite,
                ),
              ),
              pw.SizedBox(height: 12),
              _darkTable(
                fonts: fonts,
                headers: tableHeaders,
                rows: tableRows,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _documentShell({
    required _PdfFonts fonts,
    required String title,
    required String subtitle,
    required pw.MemoryImage? logo,
    required String businessName,
    required List<List<String>> businessIdentityRows,
    required List<List<String>> metaRows,
    required List<_SummaryCardData> summaryCards,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    required String notesTitle,
    required String notes,
    required String footerText,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _documentHeader(
          fonts: fonts,
          title: title,
          subtitle: subtitle,
          logo: logo,
          businessName: businessName,
          businessIdentityRows: businessIdentityRows,
        ),
        pw.SizedBox(height: 18),
        _panel(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'بيانات المستند',
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 14,
                  color: _pdfWhite,
                ),
              ),
              pw.SizedBox(height: 12),
              _metaTable(fonts: fonts, rows: metaRows),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        _summaryCardRow(
          fonts: fonts,
          cards: summaryCards,
        ),
        pw.SizedBox(height: 16),
        _panel(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'البنود',
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 14,
                  color: _pdfWhite,
                ),
              ),
              pw.SizedBox(height: 12),
              _darkTable(
                fonts: fonts,
                headers: tableHeaders,
                rows: tableRows,
              ),
            ],
          ),
        ),
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _notePanel(
            fonts: fonts,
            title: notesTitle,
            text: notes,
          ),
        ],
        if (footerText.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text(
              footerText,
              style: pw.TextStyle(
                font: fonts.base,
                fontSize: 10,
                color: _pdfSoftText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _reportHeader({
    required _PdfFonts fonts,
    required String title,
    required String subtitle,
    required String iconText,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _pdfPanel,
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: _pdfBorder, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 22,
                    color: _pdfWhite,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    font: fonts.base,
                    fontSize: 11,
                    color: _pdfSoftText,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 52,
            height: 52,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _pdfAccent,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Text(
              iconText,
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 18,
                color: _pdfBg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _documentHeader({
    required _PdfFonts fonts,
    required String title,
    required String subtitle,
    required pw.MemoryImage? logo,
    required String businessName,
    required List<List<String>> businessIdentityRows,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _pdfPanel,
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: _pdfBorder, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName.isEmpty ? 'Hasoob' : businessName,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 22,
                    color: _pdfWhite,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 15,
                    color: _pdfAccent,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      font: fonts.base,
                      fontSize: 10,
                      color: _pdfSoftText,
                    ),
                  ),
                ],
                if (businessIdentityRows.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  ...businessIdentityRows.map(
                        (row) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '${row[0]}: ${row[1]}',
                        style: pw.TextStyle(
                          font: fonts.base,
                          fontSize: 10,
                          color: _pdfSoftText,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          if (logo != null)
            pw.Container(
              width: 90,
              height: 90,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(18),
                border: pw.Border.all(
                  color: PdfColors.grey300,
                  width: 1,
                ),
              ),
              child: pw.Center(
                child: pw.Image(
                  logo,
                  fit: pw.BoxFit.contain,
                ),
              ),
            )
          else
            pw.Container(
              width: 90,
              height: 90,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: _pdfAccent,
                borderRadius: pw.BorderRadius.circular(18),
              ),
              child: pw.Text(
                'H',
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 28,
                  color: _pdfBg,
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _summaryGrid({
    required _PdfFonts fonts,
    required List<List<String>> rows,
  }) {
    final safeRows = rows.isEmpty ? <List<String>>[['-', '-']] : rows;

    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: safeRows.map((row) {
        final clean = _cleanRow(row);
        final label = clean.isNotEmpty ? clean.first : '-';
        final value = clean.length > 1 ? clean[1] : '-';

        return pw.Container(
          width: 245,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _pdfPanel,
            borderRadius: pw.BorderRadius.circular(16),
            border: pw.Border.all(color: _pdfBorder, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  font: fonts.base,
                  fontSize: 10,
                  color: _pdfMuted,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                value.isEmpty ? '-' : value,
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 12,
                  color: _pdfWhite,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _summaryCardRow({
    required _PdfFonts fonts,
    required List<_SummaryCardData> cards,
  }) {
    return pw.Row(
      children: cards
          .map(
            (card) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _pdfPanelAlt,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: _pdfBorder, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    card.label,
                    style: pw.TextStyle(
                      font: fonts.base,
                      fontSize: 10,
                      color: _pdfMuted,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    card.value,
                    style: pw.TextStyle(
                      font: fonts.bold,
                      fontSize: 13,
                      color: card.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  pw.Widget _metaTable({
    required _PdfFonts fonts,
    required List<List<String>> rows,
  }) {
    final safeRows = rows.isEmpty ? <List<String>>[['-', '-']] : rows;

    return pw.Table(
      border: pw.TableBorder.all(
        color: _pdfBorder,
        width: 0.8,
      ),
      children: safeRows.map((row) {
        final clean = _cleanRow(row);
        final label = clean.isNotEmpty ? clean[0] : '-';
        final value = clean.length > 1 ? clean[1] : '-';

        return pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: _pdfPanelAlt,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: pw.Text(
                value.isEmpty ? '-' : value,
                style: pw.TextStyle(
                  font: fonts.base,
                  fontSize: 10,
                  color: _pdfWhite,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 10,
                  color: _pdfAccent,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  pw.Widget _darkTable({
    required _PdfFonts fonts,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final safeRows = rows.isEmpty
        ? <List<String>>[
      List<String>.filled(headers.length, '-'),
    ]
        : rows.map(_cleanRow).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers.map(_cleanText).toList(),
      data: safeRows,
      headerDecoration: pw.BoxDecoration(
        color: _pdfAccent,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(10),
          topRight: pw.Radius.circular(10),
        ),
      ),
      headerStyle: pw.TextStyle(
        font: fonts.bold,
        fontSize: 10,
        color: _pdfBg,
      ),
      cellStyle: pw.TextStyle(
        font: fonts.base,
        fontSize: 9.5,
        color: _pdfWhite,
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: _pdfPanelAlt,
      ),
      rowDecoration: const pw.BoxDecoration(
        color: _pdfPanel,
      ),
      border: pw.TableBorder.all(
        color: _pdfBorder,
        width: 0.7,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      headerAlignment: pw.Alignment.centerRight,
      cellAlignment: pw.Alignment.centerRight,
    );
  }

  pw.Widget _notePanel({
    required _PdfFonts fonts,
    required String title,
    required String text,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _pdfPanel,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _pdfBorder, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: fonts.bold,
              fontSize: 12,
              color: _pdfAccent,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            text,
            style: pw.TextStyle(
              font: fonts.base,
              fontSize: 10,
              color: _pdfWhite,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _panel({required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _pdfPanel,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _pdfBorder, width: 1),
      ),
      child: child,
    );
  }

  pw.PageTheme _pageTheme(_PdfFonts fonts) {
    return pw.PageTheme(
      margin: const pw.EdgeInsets.all(26),
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.bold,
        fontFallback: [fonts.base, fonts.bold],
      ),
      textDirection: pw.TextDirection.rtl,
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(
          color: _pdfBg,
        ),
      ),
    );
  }

  Future<_PdfFonts> _loadPdfFonts() async {
    final regularFontData = await rootBundle.load(
      'assets/fonts/Cairo-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/Cairo-Bold.ttf',
    );

    return _PdfFonts(
      base: pw.Font.ttf(regularFontData),
      bold: pw.Font.ttf(boldFontData),
    );
  }

  Future<pw.MemoryImage?> _loadBusinessLogo(String? logoPath) async {
    final normalizedPath = _cleanText(logoPath);
    if (normalizedPath.isEmpty) return null;

    try {
      final file = File(normalizedPath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<File> _createFile(String prefix, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportsDirectory = Directory(p.join(directory.path, 'exports'));

    if (!await exportsDirectory.exists()) {
      await exportsDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final safePrefix = prefix.replaceAll(RegExp(r'[^\w\-]+'), '_');

    return File(
      p.join(
        exportsDirectory.path,
        '${safePrefix}_$timestamp.$extension',
      ),
    );
  }

  String _periodLabel(ReportPeriodFilter filter) {
    switch (filter) {
      case ReportPeriodFilter.all:
        return 'كل الفترات';
      case ReportPeriodFilter.last7Days:
        return 'آخر 7 أيام';
      case ReportPeriodFilter.last30Days:
        return 'آخر 30 يومًا';
      case ReportPeriodFilter.today:
        return 'اليوم';
    }
  }

  String _selectedProductLabel(List<Product> products, String? productId) {
    if (productId == null || productId.isEmpty) {
      return 'كل الأصناف';
    }
    return _productName(products, productId);
  }

  String _productName(List<Product> products, String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product.name;
      }
    }
    return 'الصنف المحدد';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _escape(dynamic value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _reportIcon(ExportReportType type) {
    switch (type) {
      case ExportReportType.inventory:
        return 'IN';
      case ExportReportType.salesHistory:
        return 'SA';
      case ExportReportType.generalSummary:
        return 'GS';
      case ExportReportType.trialBalance:
        return 'TB';
    }
  }

  String _invoiceStatusLabel(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'paid':
        return 'مدفوعة';
      case 'partially_paid':
        return 'مدفوعة جزئيًا';
      case 'overdue':
        return 'متأخرة';
      case 'draft':
        return 'مسودة';
      case 'issued':
        return 'صادرة';
      default:
        return _cleanText(status).isEmpty ? 'غير محدد' : _cleanText(status);
    }
  }

  String _quotationStatusLabel(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'draft':
        return 'مسودة';
      case 'sent':
        return 'مرسل';
      case 'accepted':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'converted_to_invoice':
        return 'تم التحويل إلى فاتورة';
      default:
        return _cleanText(status).isEmpty ? 'غير محدد' : _cleanText(status);
    }
  }
}

class _PdfFonts {
  const _PdfFonts({
    required this.base,
    required this.bold,
  });

  final pw.Font base;
  final pw.Font bold;
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final PdfColor color;
}
