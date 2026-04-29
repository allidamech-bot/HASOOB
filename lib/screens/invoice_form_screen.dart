import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../core/app_copy.dart';
import '../core/app_currency.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/models/document_line_item.dart';
import '../data/models/product_model.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/invoice_repository.dart';
import '../data/services/export_service.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({
    super.key,
    this.sourceQuotationId,
  });

  final String? sourceQuotationId;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _issueDateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _dueDateController = TextEditingController();
  final _notesController = TextEditingController();
  final _currencyController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');

  final List<DocumentLineItem> _items = [];
  final ExportService _exportService = ExportService();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  List<Map<String, dynamic>> _customers = const [];
  List<ProductModel> _products = const [];

  String? _selectedCustomerId;
  String? _selectedProductId;
  String _paymentMethod = 'cash';
  _InvoicePaymentMode _paymentMode = _InvoicePaymentMode.none;

  bool _loading = true;
  bool _saving = false;

  bool get _isFromQuotation =>
      widget.sourceQuotationId != null &&
          widget.sourceQuotationId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _dueDateController.dispose();
    _notesController.dispose();
    _currencyController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final customers = await _invoiceRepository.getCustomers();
      final products = await _invoiceRepository.getProducts();
      final profile = await _invoiceRepository.getBusinessProfile();
      final defaultNotes = profile?.defaultInvoiceNotes ?? '';

      final loadedItems = <DocumentLineItem>[];
      String? selectedCustomerId =
          customers.isNotEmpty ? customers.first['id'].toString() : null;
      var notesText = defaultNotes;
      String? currencyText;

      if (_isFromQuotation) {
        final quotation =
            await _invoiceRepository.getQuotationById(widget.sourceQuotationId!);
        final quotationItems =
            await _invoiceRepository.getQuotationItems(widget.sourceQuotationId!);

        if (quotation != null) {
          selectedCustomerId = quotation.customerName;
          notesText = quotation.notes ?? '';
          currencyText = quotation.currencyCode;

          loadedItems.addAll(
            quotationItems.map(
              (item) => DocumentLineItem(
                productId: item['product_id']?.toString() ?? '',
                productName: item['product_name']?.toString() ?? '',
                quantity: _toInt(item['quantity']),
                unitPrice: _toDouble(item['unit_price']),
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _products = products;
        _selectedCustomerId = selectedCustomerId;
        _selectedProductId = products.isNotEmpty ? products.first.id : null;
        _priceController.text =
        products.isNotEmpty ? products.first.sellingPrice.toStringAsFixed(2) : '';
        _notesController.text = notesText;
        _currencyController.text = currencyText ?? '';
        _items
          ..clear()
          ..addAll(loadedItems);
        _loading = false;
      });

      _syncPaidAmountWithMode();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppMessages.error(context, '$error');
    }
  }

  double get _total =>
      _items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get _paidAmount =>
      double.tryParse(_paidAmountController.text.trim()) ?? 0;

  double get _remaining => (_total - _paidAmount).clamp(0, _total).toDouble();

  String? get _currencyCode =>
      AppCurrency.sanitizeLabel(_currencyController.text);

  ProductModel? _findProduct(String? productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initialDate =
        DateTime.tryParse(controller.text.trim()) ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || pickedDate == null) return;

    final month = pickedDate.month.toString().padLeft(2, '0');
    final day = pickedDate.day.toString().padLeft(2, '0');

    setState(() {
      controller.text = '${pickedDate.year}-$month-$day';
    });
  }

  void _syncPaidAmountWithMode() {
    if (_paymentMode == _InvoicePaymentMode.none) {
      _paidAmountController.text = '0';
    } else if (_paymentMode == _InvoicePaymentMode.full) {
      _paidAmountController.text = _total.toStringAsFixed(2);
    } else {
      final current = double.tryParse(_paidAmountController.text.trim()) ?? 0;
      _paidAmountController.text =
          current.clamp(0, _total).toStringAsFixed(2);
    }

    if (mounted) setState(() {});
  }

  void _setPaymentMode(_InvoicePaymentMode mode) {
    setState(() => _paymentMode = mode);
    _syncPaidAmountWithMode();
  }

  void _addItem() {
    final copy = AppCopy.of(context);
    final product = _findProduct(_selectedProductId);
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    if (product == null || qty <= 0 || price < 0) {
      AppMessages.error(context, copy.t('checkProductQtyPrice'));
      return;
    }

    setState(() {
      _items.add(
        DocumentLineItem(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          unitPrice: price,
        ),
      );
      _qtyController.text = '1';
      _priceController.text = product.sellingPrice.toStringAsFixed(2);
    });

    if (_paymentMode != _InvoicePaymentMode.none) {
      _syncPaidAmountWithMode();
    }
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;

    setState(() {
      _items.removeAt(index);
    });

    if (_paymentMode != _InvoicePaymentMode.none) {
      _syncPaidAmountWithMode();
    }
  }

  Future<void> _openAddCustomerDialog() async {
    final copy = AppCopy.of(context);
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(copy.t('addCustomerTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: copy.t('addCustomer'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: copy.t('phone'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: copy.t('addressOrNotes'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(copy.t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (nameController.text.trim().isEmpty) {
                    throw Exception(copy.t('customerNameRequired'));
                  }

                  await _customerRepository.saveCustomer({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'notes': notesController.text.trim(),
                  });

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  AppMessages.error(dialogContext, '$error');
                }
              },
              child: Text(copy.t('save')),
            ),
          ],
        );
      },
    );

    final createdName = nameController.text.trim();
    final createdPhone = phoneController.text.trim();

    nameController.dispose();
    phoneController.dispose();
    notesController.dispose();

    if (created != true) return;

    final refreshedCustomers = await _customerRepository.getCustomers();
    if (!mounted) return;

    String? selectedId;
    for (final customer in refreshedCustomers.reversed) {
      final name = customer['name']?.toString().trim() ?? '';
      final phone = customer['phone']?.toString().trim() ?? '';
      if (name == createdName && phone == createdPhone) {
        selectedId = customer['id']?.toString();
        break;
      }
    }

    selectedId ??=
    refreshedCustomers.isNotEmpty ? refreshedCustomers.last['id']?.toString() : null;

    setState(() {
      _customers = refreshedCustomers;
      _selectedCustomerId = selectedId;
    });

    AppMessages.success(context, copy.t('customerCreated'));
  }

  Future<void> _submit(String status) async {
    final copy = AppCopy.of(context);

    if (_selectedCustomerId == null || _items.isEmpty) {
      AppMessages.error(
        context,
        _selectedCustomerId == null
            ? copy.t('customerRequired')
            : copy.t('atLeastOneItem'),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final paidAmount = status == 'draft'
          ? 0.0
          : (double.tryParse(_paidAmountController.text.trim()) ?? 0)
          .clamp(0, _total)
          .toDouble();

      if (status != 'draft' &&
          _paymentMode == _InvoicePaymentMode.partial &&
          paidAmount <= 0) {
        throw Exception(copy.t('partialPaymentValid'));
      }

      final invoiceId = await _invoiceRepository.createInvoice(
        customerId: _selectedCustomerId!,
        quotationId: widget.sourceQuotationId,
        items: _items.map((item) => item.toMap()).toList(),
        status: status,
        issueDate: _issueDateController.text.trim().isEmpty
            ? null
            : _issueDateController.text.trim(),
        dueDate: _dueDateController.text.trim().isEmpty
            ? null
            : _dueDateController.text.trim(),
        notes: _notesController.text.trim(),
        paidAmount: paidAmount,
        paymentMethod: paidAmount <= 0 ? 'on_account' : _paymentMethod,
        currencyCode: _currencyCode,
      );

      if (status == 'issued') {
        await _handleIssuedInvoice(invoiceId);
      } else if (mounted) {
        AppMessages.success(context, copy.t('invoiceDraftSaved'));
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '$error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _handleIssuedInvoice(String invoiceId) async {
    final copy = AppCopy.of(context);

    final invoice = await _invoiceRepository.getInvoiceById(invoiceId);
    final items = await _invoiceRepository.getInvoiceItems(invoiceId);
    final businessProfile = await _invoiceRepository.getBusinessProfile();

    if (invoice == null) {
      throw Exception(copy.t('invoiceSavedNotFound'));
    }

    final pdfPath = await _exportService.generateInvoicePdf(
      invoice: invoice,
      items: items,
      businessProfile: businessProfile,
    );

    await _invoiceRepository.updateInvoicePdfPath(
      invoiceId: invoiceId,
      pdfPath: pdfPath,
    );

    if (!mounted) return;

    AppMessages.success(context, '${copy.t('invoiceSavedPdf')}\n$pdfPath');

    final action = await showDialog<_InvoicePdfAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(copy.t('invoiceCreated')),
          content: Text(copy.t('previewOrShareNow')),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _InvoicePdfAction.close),
              child: Text(copy.t('later')),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _InvoicePdfAction.share),
              child: Text(copy.t('share')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _InvoicePdfAction.preview),
              child: Text(copy.t('preview')),
            ),
          ],
        );
      },
    );

    if (action == _InvoicePdfAction.preview) {
      await _previewInvoicePdf(pdfPath);
    } else if (action == _InvoicePdfAction.share) {
      await _shareInvoicePdf(pdfPath);
    }
  }

  Future<void> _previewInvoicePdf(String pdfPath) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      if (!mounted) return;
      AppMessages.error(context, AppCopy.of(context).t('pdfMissing'));
      return;
    }

    final bytes = await file.readAsBytes();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InvoicePdfPreviewScreen(
          title: p.basename(pdfPath),
          bytes: bytes,
        ),
      ),
    );
  }

  Future<void> _shareInvoicePdf(String pdfPath) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      if (!mounted) return;
      AppMessages.error(context, AppCopy.of(context).t('pdfMissing'));
      return;
    }

    final bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: p.basename(pdfPath));
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final remaining = _remaining;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isFromQuotation
              ? copy.t('invoiceFromQuotationTitle')
              : copy.t('createInvoiceTitle'),
        ),
      ),
      body: _loading
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      )
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          if (_isFromQuotation) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.transform_rounded,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy.t('quotationLoadedBanner'),
                      style: TextStyle(
                        color: AppTheme.textSecondaryFor(context),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _sectionCard(
            context,
            title: copy.t('invoiceInfo'),
            icon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCustomerId,
                        decoration: InputDecoration(
                          labelText: copy.t('customer'),
                        ),
                        items: _customers
                            .map(
                              (customer) => DropdownMenuItem<String>(
                            value: customer['id'].toString(),
                            child: Text(
                              customer['name']?.toString() ?? '',
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: _isFromQuotation
                            ? null
                            : (value) {
                          setState(() => _selectedCustomerId = value);
                        },
                      ),
                    ),
                    if (!_isFromQuotation) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _openAddCustomerDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(copy.t('customer')),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _issueDateController,
                  readOnly: true,
                  onTap: () => _pickDate(_issueDateController),
                  decoration: InputDecoration(
                    labelText: copy.t('invoiceDate'),
                    helperText: copy.t('pickDate'),
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dueDateController,
                  readOnly: true,
                  onTap: () => _pickDate(_dueDateController),
                  decoration: InputDecoration(
                    labelText: copy.t('dueDate'),
                    helperText: copy.t('optional'),
                    suffixIcon: const Icon(Icons.event_available_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: copy.t('currencyOptional'),
                    helperText: copy.t('currencyExample'),
                    prefixIcon:
                    const Icon(Icons.currency_exchange_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _itemBuilder(copy),
          const SizedBox(height: 16),
          _sectionCard(
            context,
            title: copy.t('paymentAndNotes'),
            icon: Icons.account_balance_wallet_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.t('collectionMethod'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(copy.t('noPayment')),
                      selected: _paymentMode == _InvoicePaymentMode.none,
                      onSelected: (_) =>
                          _setPaymentMode(_InvoicePaymentMode.none),
                    ),
                    ChoiceChip(
                      label: Text(copy.t('partialPayment')),
                      selected: _paymentMode == _InvoicePaymentMode.partial,
                      onSelected: (_) =>
                          _setPaymentMode(_InvoicePaymentMode.partial),
                    ),
                    ChoiceChip(
                      label: Text(copy.t('fullPayment')),
                      selected: _paymentMode == _InvoicePaymentMode.full,
                      onSelected: (_) =>
                          _setPaymentMode(_InvoicePaymentMode.full),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_paymentMode == _InvoicePaymentMode.partial) ...[
                  TextField(
                    controller: _paidAmountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim()) ?? 0;
                      if (parsed >= _total && _total > 0) {
                        _setPaymentMode(_InvoicePaymentMode.full);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: copy.t('paidNow'),
                      helperText:
                      copy.isEnglish ? 'Example: 250' : 'مثال: 250',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_paymentMode != _InvoicePaymentMode.none) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
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
                      setState(() => _paymentMethod = value ?? 'cash');
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: copy.t('notes'),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAltFor(context),
                    borderRadius:
                    BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      _summaryRow(
                        copy.t('total'),
                        AppFormatters.currency(
                          _total,
                          currencyLabel: _currencyCode,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _summaryRow(
                        copy.t('paid'),
                        AppFormatters.currency(
                          _paidAmount,
                          currencyLabel: _currencyCode,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _summaryRow(
                        copy.t('remaining'),
                        AppFormatters.currency(
                          remaining,
                          currencyLabel: _currencyCode,
                        ),
                        accent: remaining > 0
                            ? AppTheme.warning
                            : AppTheme.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _submit('draft'),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(copy.t('saveDraft')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _submit('issued'),
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(copy.t('issueInvoice')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemBuilder(AppCopy copy) {
    return _sectionCard(
      context,
      title: _isFromQuotation
          ? copy.t('quotationItemsConverted')
          : copy.t('invoiceItemsTitle'),
      icon: Icons.inventory_2_rounded,
      child: Column(
        children: [
          if (!_isFromQuotation) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              decoration: InputDecoration(
                labelText: copy.t('product'),
              ),
              items: _products
                  .map(
                    (product) => DropdownMenuItem<String>(
                  value: product.id,
                  child: Text(product.name),
                ),
              )
                  .toList(),
              onChanged: (value) {
                final product = _findProduct(value);
                setState(() {
                  _selectedProductId = value;
                  if (product != null) {
                    _priceController.text =
                        product.sellingPrice.toStringAsFixed(2);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: copy.t('quantity'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: copy.t('unitPrice'),
                      helperText:
                      _currencyCode ?? copy.t('noCurrencySpecified'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded),
                label: Text(copy.t('addItem')),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltFor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Text(
                copy.t('noItemsYet'),
                style: TextStyle(
                  color: AppTheme.textSecondaryFor(context),
                ),
              ),
            )
          else
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAltFor(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.borderFor(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              copy
                                  .t('qtyPriceLine')
                                  .replaceAll('{qty}', '${item.quantity}')
                                  .replaceAll(
                                '{price}',
                                AppFormatters.currency(
                                  item.unitPrice,
                                  currencyLabel: _currencyCode,
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
                                  item.lineTotal,
                                  currencyLabel: _currencyCode,
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isFromQuotation)
                        IconButton(
                          onPressed: () => _removeItemAt(index),
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppTheme.danger,
                          tooltip: copy.t('delete'),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sectionCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Widget child,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
      String label,
      String value, {
        Color? accent,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ],
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum _InvoicePdfAction { preview, share, close }

enum _InvoicePaymentMode { none, partial, full }

class _InvoicePdfPreviewScreen extends StatelessWidget {
  const _InvoicePdfPreviewScreen({
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