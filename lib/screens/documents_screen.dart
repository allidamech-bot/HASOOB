import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../core/app_copy.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/models/invoice_model.dart';
import '../data/models/quotation_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_profile_repository.dart';
import '../data/repositories/invoice_repository.dart';
import '../data/services/export_service.dart';
import 'invoice_details_screen.dart';
import 'invoice_form_screen.dart';
import 'quotation_details_screen.dart';
import 'quotation_form_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _repo = InvoiceRepository();
  final _profileRepo = BusinessProfileRepository();
  final _export = ExportService();

  String get _businessId => AuthRepository.instance.currentUser?.businessId ?? AuthRepository.fallbackBusinessId;

  bool _showInvoices = true;
  int _refreshKey = 0;

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  Future<void> _create() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        _showInvoices ? const InvoiceFormScreen() : const QuotationFormScreen(),
      ),
    );

    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  Future<void> _convert(Map<String, dynamic> quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceFormScreen(
          sourceQuotationId: quotation['id']?.toString(),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  Future<String> _invoicePdf(InvoiceModel invoice) async {
    final copy = AppCopy.of(context);
    final id = invoice.id;
    final current = invoice.pdfPath ?? '';

    if (current.isNotEmpty && await File(current).exists()) {
      return current;
    }

    final fresh = await _repo.getInvoiceById(id, _businessId);
    if (fresh == null) {
      throw Exception(copy.t('documentsErrorInvoiceNotFound'));
    }

    final items = await _repo.getInvoiceItems(id, _businessId);
    final profile = await _profileRepo.getBusinessProfile(_businessId);

    final path = await _export.generateInvoicePdf(
      invoice: fresh,
      items: items,
      businessProfile: profile,
    );

    await _repo.updateInvoicePdfPath(
      businessId: _businessId,
      invoiceId: id,
      pdfPath: path,
    );
    return path;
  }

  Future<String> _quotationPdf(QuotationModel quotation) async {
    final copy = AppCopy.of(context);
    final id = quotation.id;
    final current = quotation.pdfPath ?? '';

    if (current.isNotEmpty && await File(current).exists()) {
      return current;
    }

    final fresh = await _repo.getQuotationById(id, _businessId);
    if (fresh == null) {
      throw Exception(copy.t('documentsErrorQuotationNotFound'));
    }

    final items = await _repo.getQuotationItems(id, _businessId);
    final profile = await _profileRepo.getBusinessProfile(_businessId);

    final path = await _export.generateQuotationPdf(
      quotation: fresh,
      items: items,
      businessProfile: profile,
    );

    await _repo.updateQuotationPdfPath(
      businessId: _businessId,
      quotationId: id,
      pdfPath: path,
    );
    return path;
  }

  Future<void> _preview(String path) async {
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
  }

  Future<void> _share(String path) async {
    final bytes = await File(path).readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: p.basename(path));
  }

  Future<void> _deleteInvoice(String id) async {
    await _repo.deleteInvoice(id, _businessId);

    if (!mounted) return;

    setState(() => _refreshKey++);
    AppMessages.success(
      context,
      AppCopy.of(context).documentsDeleteInvoiceSuccess(),
    );
  }

  Future<void> _deleteQuotation(String id) async {
    await _repo.deleteQuotation(id, _businessId);

    if (!mounted) return;

    setState(() => _refreshKey++);
    AppMessages.success(
      context,
      AppCopy.of(context).documentsDeleteQuotationSuccess(),
    );
  }

  double _parseAmount(String text) {
    final normalized = text.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _addPayment(InvoiceModel invoice) async {
    final copy = AppCopy.of(context);
    final controller = TextEditingController();
    String paymentMethod = 'cash';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            copy.documentsAddPaymentTitle(
              invoice.invoiceNumber,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: copy.t('amount'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: InputDecoration(
                  labelText: copy.t('paymentMethod'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text(copy.t('cash')),
                  ),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text(copy.t('bankTransfer')),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    paymentMethod = value ?? 'cash';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(copy.t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final amount = _parseAmount(controller.text);

                if (amount <= 0) {
                  AppMessages.error(dialogContext, copy.t('enterValidAmount'));
                  return;
                }

                await _repo.addInvoicePayment(
                  businessId: _businessId,
                  invoiceId: invoice.id,
                  amount: amount,
                  paymentMethod: paymentMethod,
                );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(copy.t('savePayment')),
            ),
          ],
        ),
      ),
    ) ??
        false;

    controller.dispose();

    if (!mounted || !saved) return;

    setState(() => _refreshKey++);
    AppMessages.success(context, copy.documentsPaymentSavedSuccess());
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final stream = _showInvoices ? _repo.watchInvoices(_businessId) : _repo.watchQuotations(_businessId);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('documents')),
        actions: [
          IconButton(
            onPressed: _create,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: Icon(
          _showInvoices ? Icons.receipt_long_rounded : Icons.request_quote_rounded,
        ),
        label: Text(
          _showInvoices ? copy.t('newInvoice') : copy.t('quotations'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<Object>>(
          key: ValueKey('${_showInvoices}_$_refreshKey'),
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final rows = snapshot.data ?? const <Object>[];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(copy.t('documentsTabInvoices')),
                      selected: _showInvoices,
                      onSelected: (_) {
                        if (_showInvoices) return;
                        setState(() {
                          _showInvoices = true;
                          _refreshKey++;
                        });
                      },
                    ),
                    ChoiceChip(
                      label: Text(copy.t('documentsTabQuotations')),
                      selected: !_showInvoices,
                      onSelected: (_) {
                        if (!_showInvoices) return;
                        setState(() {
                          _showInvoices = false;
                          _refreshKey++;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 46,
                            color: AppTheme.textSecondaryFor(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            copy.t('noDocuments'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...rows.map(
                        (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _showInvoices
                          ? _invoiceCard(row as InvoiceModel, copy)
                          : _quotationCard(row as QuotationModel, copy),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _invoiceCard(InvoiceModel invoice, AppCopy copy) {
    final total = invoice.total;
    final paid = invoice.paidAmount;
    final remaining = invoice.remainingAmount;
    final currencyCode = invoice.currencyCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invoice.invoiceNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              invoice.customerName.trim().isNotEmpty == true
                  ? invoice.customerName
                  : copy.documentsCustomerFallback(),
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  copy.t('total'),
                  AppFormatters.currency(total, currencyLabel: currencyCode),
                ),
                _chip(
                  copy.t('paid'),
                  AppFormatters.currency(paid, currencyLabel: currencyCode),
                ),
                _chip(
                  copy.t('remaining'),
                  AppFormatters.currency(remaining, currencyLabel: currencyCode),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceDetailsScreen(
                          invoiceId: invoice.id,
                        ),
                      ),
                    );
                  },
                  child: Text(copy.t('details')),
                ),
                OutlinedButton(
                  onPressed: () => _addPayment(invoice),
                  child: Text(copy.t('addPayment')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await _preview(await _invoicePdf(invoice));
                    } catch (error) {
                      if (!mounted) return;
                      AppMessages.error(context, '$error');
                    }
                  },
                  child: Text(copy.t('pdfPreview')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await _share(await _invoicePdf(invoice));
                    } catch (error) {
                      if (!mounted) return;
                      AppMessages.error(context, '$error');
                    }
                  },
                  child: Text(copy.t('pdfShare')),
                ),
                OutlinedButton(
                  onPressed: () => _deleteInvoice(invoice.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                  child: Text(copy.t('delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quotationCard(QuotationModel quotation, AppCopy copy) {
    final total = quotation.total;
    final currencyCode = quotation.currencyCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quotation.quotationNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              quotation.customerName.trim().isNotEmpty == true
                  ? quotation.customerName
                  : copy.documentsCustomerFallback(),
              style: TextStyle(
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
            const SizedBox(height: 10),
            _chip(
              copy.t('total'),
              AppFormatters.currency(total, currencyLabel: currencyCode),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuotationDetailsScreen(
                          quotationId: quotation.id,
                        ),
                      ),
                    );
                  },
                  child: Text(copy.t('details')),
                ),
                OutlinedButton(
                  onPressed: () => _convert(quotation.toMap()),
                  child: Text(copy.t('convertToInvoice')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await _preview(await _quotationPdf(quotation));
                    } catch (error) {
                      if (!mounted) return;
                      AppMessages.error(context, '$error');
                    }
                  },
                  child: Text(copy.t('pdfPreview')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await _share(await _quotationPdf(quotation));
                    } catch (error) {
                      if (!mounted) return;
                      AppMessages.error(context, '$error');
                    }
                  },
                  child: Text(copy.t('pdfShare')),
                ),
                OutlinedButton(
                  onPressed: () => _deleteQuotation(quotation.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                  child: Text(copy.t('delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.borderFor(context),
        ),
      ),
      child: Text(
        AppCopy.of(context).documentsChipLine(label, value),
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
      appBar: AppBar(
        title: Text(title),
      ),
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