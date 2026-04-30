import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/models/quotation_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_profile_repository.dart';
import '../data/repositories/invoice_repository.dart';
import '../data/services/export_service.dart';
import 'invoice_form_screen.dart';

class QuotationDetailsScreen extends StatefulWidget {
  const QuotationDetailsScreen({
    super.key,
    required this.quotationId,
  });

  final String quotationId;

  @override
  State<QuotationDetailsScreen> createState() => _QuotationDetailsScreenState();
}

class _QuotationDetailsScreenState extends State<QuotationDetailsScreen> {
  late final InvoiceRepository _repository;
  late final Future<_QuotationDetailsData?> _screenFuture;

  bool _isPreviewingPdf = false;
  bool _isSharingPdf = false;

  @override
  void initState() {
    super.initState();
    _repository = InvoiceRepository();
    _screenFuture = _loadScreenData();
  }

  String get _businessId => AuthRepository.instance.currentUser?.businessId ?? AuthRepository.fallbackBusinessId;

  Future<_QuotationDetailsData?> _loadScreenData() async {
    final quotation = await _repository.getQuotationById(_businessId, widget.quotationId);
    if (quotation == null) return null;

    final items = await _repository.getQuotationItems(_businessId, widget.quotationId);
    return _QuotationDetailsData(
      quotation: quotation,
      items: items,
    );
  }

  Future<String> _getPdfPath(QuotationModel quotation) async {
    final current = quotation.pdfPath ?? '';
    if (current.isNotEmpty && await File(current).exists()) {
      return current;
    }

    final profileRepo = BusinessProfileRepository();
    final export = ExportService();

    final items = await _repository.getQuotationItems(_businessId, widget.quotationId);
    final profile = await profileRepo.getBusinessProfile(_businessId);

    final path = await export.generateQuotationPdf(
      quotation: quotation,
      items: items,
      businessProfile: profile,
    );

    await _repository.updateQuotationPdfPath(
      businessId: _businessId,
      quotationId: widget.quotationId,
      pdfPath: path,
    );

    return path;
  }

  Future<void> _previewPdf(QuotationModel quotation) async {
    if (_isPreviewingPdf) return;

    setState(() => _isPreviewingPdf = true);

    try {
      final path = await _getPdfPath(quotation);
      final bytes = await File(path).readAsBytes();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewScreen(
            title: p.basename(path),
            bytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppMessages.error(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isPreviewingPdf = false);
      }
    }
  }

  Future<void> _sharePdf(QuotationModel quotation) async {
    if (_isSharingPdf) return;

    setState(() => _isSharingPdf = true);

    try {
      final path = await _getPdfPath(quotation);
      final bytes = await File(path).readAsBytes();
      await Printing.sharePdf(bytes: bytes, filename: p.basename(path));
    } catch (e) {
      if (!mounted) return;
      AppMessages.error(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSharingPdf = false);
      }
    }
  }

  bool _canConvertToInvoice(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized != 'declined' && normalized != 'expired';
  }

  Future<void> _openInvoiceFromQuotation(QuotationModel quotation) async {
    final status = quotation.status;
    if (!_canConvertToInvoice(status)) {
      AppMessages.error(
        context,
        AppCopy.of(context).t('quotationCannotBeConverted'),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceFormScreen(
          sourceQuotationId: quotation.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('quotationDetailsTitle')),
      ),
      body: FutureBuilder<_QuotationDetailsData?>(
        future: _screenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _QuotationDetailsLoadingView();
          }

          if (snapshot.hasError) {
            return _QuotationDetailsMessageView(
              icon: Icons.error_outline_rounded,
              message: copy.t('somethingWentWrong'),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _QuotationDetailsMessageView(
              icon: Icons.find_in_page_outlined,
              message: copy.t('quotationNotFound'),
            );
          }

          final quotation = data.quotation;
          final items = data.items;
          final currencyCode = quotation.currencyCode;
          final status = quotation.status;
          final canConvert = _canConvertToInvoice(status);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quotation.quotationNumber,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(
                            label: _statusLabel(status, copy),
                            status: status,
                          ),
                          if (currencyCode?.trim().isNotEmpty ?? false)
                            _MetaChip(
                              icon: Icons.payments_outlined,
                              label: currencyCode!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _detailRow(
                        context,
                        copy.t('customer'),
                        quotation.customerName.trim().isNotEmpty == true
                            ? quotation.customerName
                            : copy.documentsCustomerFallback(),
                      ),
                      _detailRow(
                        context,
                        copy.t('issueDate'),
                        AppFormatters.dateTimeString(
                          quotation.issueDate.toIso8601String(),
                        ),
                      ),
                      _detailRow(
                        context,
                        copy.t('expiryDate'),
                        quotation.expiryDate != null
                            ? AppFormatters.dateTimeString(
                          quotation.expiryDate!.toIso8601String(),
                        )
                            : '-',
                      ),
                      _detailRow(
                        context,
                        copy.t('notes'),
                        quotation.notes?.trim().isNotEmpty == true
                            ? quotation.notes!
                            : '-',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.t('items'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        _EmptyItemsState(copy: copy)
                      else
                        ...items.map((item) {
                          final quantity = _sanitizeInt(item['quantity']);
                          final unitPrice = _sanitizeMoney(item['unit_price']);
                          final lineTotal = _sanitizeMoney(item['line_total']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAltFor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.borderFor(context),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['product_name']?.toString().trim().isNotEmpty == true
                                      ? item['product_name'].toString()
                                      : '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  copy
                                      .t('qtyPriceLine')
                                      .replaceAll('{qty}', '$quantity')
                                      .replaceAll(
                                    '{price}',
                                    AppFormatters.currency(
                                      unitPrice,
                                      currencyLabel: currencyCode,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryFor(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  copy.t('lineTotal').replaceAll(
                                    '{value}',
                                    AppFormatters.currency(
                                      lineTotal,
                                      currencyLabel: currencyCode,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _summaryRow(
                    context,
                    copy.t('total'),
                    quotation.total,
                    currencyCode: currencyCode,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canConvert
                          ? () => _openInvoiceFromQuotation(quotation)
                          : null,
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text(copy.t('convertToInvoice')),
                    ),
                  ),
                ],
              ),
              if (!canConvert) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    copy.t('quotationCannotBeConverted'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPreviewingPdf || _isSharingPdf
                          ? null
                          : () => _previewPdf(quotation),
                      icon: _isPreviewingPdf
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(copy.t('pdfPreview')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPreviewingPdf || _isSharingPdf
                          ? null
                          : () => _sharePdf(quotation),
                      icon: _isSharingPdf
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.share_rounded),
                      label: Text(copy.t('pdfShare')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      BuildContext context,
      String label,
      double value, {
        String? currencyCode,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          AppFormatters.currency(value, currencyLabel: currencyCode),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status, AppCopy copy) {
    switch (status.trim().toLowerCase()) {
      case 'sent':
        return copy.t('statusSent');
      case 'accepted':
        return copy.t('statusAccepted');
      case 'declined':
        return copy.t('statusDeclined');
      case 'expired':
        return copy.t('statusExpired');
      case 'draft':
        return copy.t('statusDraft');
      default:
        return status.trim().isEmpty ? copy.t('statusUnknown') : status;
    }
  }

  double _sanitizeMoney(dynamic value) {
    final parsed = _toDouble(value);
    return parsed < 0 ? 0 : parsed;
  }

  int _sanitizeInt(dynamic value) {
    final parsed = _toInt(value);
    return parsed < 0 ? 0 : parsed;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _QuotationDetailsData {
  const _QuotationDetailsData({
    required this.quotation,
    required this.items,
  });

  final QuotationModel quotation;
  final List<Map<String, dynamic>> items;
}

class _QuotationDetailsLoadingView extends StatelessWidget {
  const _QuotationDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _QuotationDetailsMessageView extends StatelessWidget {
  const _QuotationDetailsMessageView({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState({
    required this.copy,
  });

  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppTheme.textSecondaryFor(context),
          ),
          const SizedBox(height: 8),
          Text(
            copy.t('noItemsAvailable'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.textSecondaryFor(context),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.status,
  });

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    Color borderColor;
    Color textColor;
    IconData icon;

    switch (normalized) {
      case 'accepted':
        borderColor = Colors.green;
        textColor = Colors.green;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'declined':
        borderColor = Colors.red;
        textColor = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case 'expired':
        borderColor = Colors.orange;
        textColor = Colors.orange;
        icon = Icons.schedule_rounded;
        break;
      case 'sent':
        borderColor = Colors.blue;
        textColor = Colors.blue;
        icon = Icons.send_rounded;
        break;
      default:
        borderColor = AppTheme.borderFor(context);
        textColor = AppTheme.textSecondaryFor(context);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({
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