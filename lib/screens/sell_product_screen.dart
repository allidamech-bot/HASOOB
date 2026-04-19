import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_currency.dart';
import '../core/app_formatters.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/models/product.dart';
import '../data/repositories/product_repository.dart';

class SellProductScreen extends StatefulWidget {
  const SellProductScreen({super.key, required this.product});

  final Product product;

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final ProductRepository _productRepository = ProductRepository();

  final TextEditingController _qtyController = TextEditingController(text: '1');
  late final TextEditingController _priceController;
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.product.sellingPrice.toStringAsFixed(2),
    );

    _qtyController.addListener(_handleInputChanged);
    _priceController.addListener(_handleInputChanged);
    _currencyController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _qtyController.removeListener(_handleInputChanged);
    _priceController.removeListener(_handleInputChanged);
    _currencyController.removeListener(_handleInputChanged);
    _qtyController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _customerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  int get _qty => int.tryParse(_qtyController.text.trim()) ?? 0;

  double get _enteredUnitPrice =>
      double.tryParse(_priceController.text.trim()) ?? 0;

  String? get _currencyCode => AppCurrency.sanitizeLabel(_currencyController.text);

  double get _enteredTotal => _qty * _enteredUnitPrice;

  double get _profitValue =>
      _qty * (_enteredUnitPrice - widget.product.landedCost);

  String? get _validationMessage {
    final copy = AppCopy.of(context);
    if (_qty <= 0) {
      return copy.t('sellInvalidQty');
    }
    if (_qty > widget.product.stockQty) {
      return copy.t('sellQtyTooHigh');
    }
    if (_enteredUnitPrice < 0) {
      return copy.t('sellNegativePrice');
    }
    return null;
  }

  bool get _canSubmit => !_isSubmitting && _validationMessage == null;

  Future<void> _sell() async {
    final copy = AppCopy.of(context);
    final validationMessage = _validationMessage;
    if (validationMessage != null) {
      AppMessages.error(context, validationMessage);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      await _productRepository.sellProduct(
        productId: widget.product.id,
        qty: _qty,
        sellingPrice: _enteredUnitPrice,
        customerName: _customerController.text.trim(),
        saleNote: _noteController.text.trim(),
        currencyCode: _currencyCode,
      );

      if (!mounted) return;
      AppMessages.success(context, copy.t('sellSuccess'));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('sellError')}\n$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final validationMessage = _validationMessage;
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.sellProductTitle(product.name))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(copy.sellAvailableStock(product.stockQty, product.unit)),
                    Text(copy.sellDefaultPrice(
                      AppFormatters.currency(product.sellingPrice),
                    )),
                    Text(copy.sellUnitCost(
                      AppFormatters.currency(product.landedCost),
                    )),
                    const SizedBox(height: 6),
                    Text(
                      copy.sellExpectedProfit(
                        AppFormatters.currency(product.netProfit),
                      ),
                      style: TextStyle(
                        color: product.netProfit >= 0
                            ? AppTheme.success
                            : AppTheme.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currencyController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: copy.t('currencyOptional'),
                helperText: copy.t('currencyExample'),
                prefixIcon: const Icon(Icons.currency_exchange_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: copy.t('quantity'),
                prefixIcon: const Icon(Icons.confirmation_number_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: copy.t('sellingPrice'),
                helperText: _currencyCode ?? copy.t('noCurrencySpecified'),
                prefixIcon: const Icon(Icons.sell_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerController,
              decoration: InputDecoration(
                labelText: copy.t('customerNameOptional'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: copy.t('noteOptional'),
                prefixIcon: const Icon(Icons.notes_rounded),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryRow(
                      copy.t('saleTotal'),
                      AppFormatters.currency(
                        _enteredTotal,
                        currencyLabel: _currencyCode,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(
                      copy.t('expectedProfit'),
                      AppFormatters.currency(
                        _profitValue,
                        currencyLabel: _currencyCode,
                      ),
                      valueColor: _profitValue >= 0
                          ? AppTheme.success
                          : AppTheme.danger,
                    ),
                  ],
                ),
              ),
            ),
            if (validationMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        validationMessage,
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _canSubmit ? _sell : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _isSubmitting ? copy.t('submittingSale') : copy.t('confirmSale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
