import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';

enum _AdjustmentMode { stock, cost }

class InventoryAdjustmentScreen extends StatefulWidget {
  const InventoryAdjustmentScreen({super.key, required this.product});
  final ProductModel product;
  @override
  State<InventoryAdjustmentScreen> createState() => _InventoryAdjustmentScreenState();
}

class _InventoryAdjustmentScreenState extends State<InventoryAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _productRepository = ProductRepository();
  late final TextEditingController _stockQtyController,_purchasePriceController,_extraCostsController;
  final TextEditingController _reasonController = TextEditingController();
  _AdjustmentMode _mode = _AdjustmentMode.stock;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _stockQtyController = TextEditingController(text: widget.product.stockQty.toString());
    _purchasePriceController = TextEditingController(text: widget.product.purchasePrice.toString());
    _extraCostsController = TextEditingController(text: widget.product.extraCosts.toString());
  }
  @override
  void dispose() { _stockQtyController.dispose(); _purchasePriceController.dispose(); _extraCostsController.dispose(); _reasonController.dispose(); super.dispose(); }

  Future<void> _save() async {
    final copy = AppCopy.of(context);
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _productRepository.applyInventoryAdjustment(
        productId: widget.product.id,
        newStockQty: _mode == _AdjustmentMode.stock ? _toInt(_stockQtyController.text) : null,
        newPurchasePrice: _mode == _AdjustmentMode.cost ? _toDouble(_purchasePriceController.text) : null,
        newExtraCosts: _mode == _AdjustmentMode.cost ? _toDouble(_extraCostsController.text) : null,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      AppMessages.success(context, copy.t('adjustSaved'));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('adjustSaveError')}\n$error');
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isStockMode = _mode == _AdjustmentMode.stock;
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('adjustInventoryCostTitle'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(copy.t('adjustSingleMode'), style: TextStyle(color: AppTheme.textSecondaryFor(context))),
            const SizedBox(height: 16),
            SegmentedButton<_AdjustmentMode>(
              segments: [
                ButtonSegment(value: _AdjustmentMode.stock, icon: const Icon(Icons.inventory_2_rounded), label: Text(copy.t('adjustStockQty'))),
                ButtonSegment(value: _AdjustmentMode.cost, icon: const Icon(Icons.price_change_rounded), label: Text(copy.t('adjustCost'))),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() => _mode = value.first),
            ),
            const SizedBox(height: 16),
            if (isStockMode) ...[
              TextFormField(
                controller: _stockQtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: copy.t('newBalance'),
                  helperText: copy.t('currentBalance').replaceAll('{value}', '${widget.product.stockQty}'),
                ),
                validator: (value) => _validateNumber(value, copy.t('newBalance'), integer: true),
              ),
            ] else ...[
              TextFormField(
                controller: _purchasePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: copy.t('newPurchasePrice'),
                  helperText: copy.t('currentValue').replaceAll('{value}', widget.product.purchasePrice.toStringAsFixed(2)),
                ),
                validator: (value) => _validateNumber(value, copy.t('newPurchasePrice')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extraCostsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: copy.t('newExtraCosts'),
                  helperText: copy.t('currentValue').replaceAll('{value}', widget.product.extraCosts.toStringAsFixed(2)),
                ),
                validator: (value) => _validateNumber(value, copy.t('newExtraCosts')),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: copy.t('adjustReason'),
                helperText: copy.t('adjustReasonHelp'),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return copy.t('adjustReasonRequired');
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              isStockMode ? copy.t('stockAdjustHelp') : copy.t('costAdjustHelp'),
              style: TextStyle(color: AppTheme.textSecondaryFor(context), fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : Text(copy.t('saveAdjustment')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateNumber(String? value, String fieldName, {bool integer = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return AppCopy.of(context).requiredField(fieldName);
    final number = integer ? int.tryParse(text) : double.tryParse(text);
    if (number == null) return AppCopy.of(context).t('fieldInvalid').replaceAll('{field}', fieldName);
    if (number < 0) {
      return AppCopy.of(context).isEnglish ? '$fieldName cannot be negative.' : '$fieldName لا يمكن أن يكون سالبًا.';
    }
    return null;
  }

  double _toDouble(String value) => double.tryParse(value.trim()) ?? 0;
  int _toInt(String value) => int.tryParse(value.trim()) ?? 0;
}
