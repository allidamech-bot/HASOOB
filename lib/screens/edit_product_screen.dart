import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_messages.dart';
import '../data/models/product_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/product_repository.dart';

class EditProductScreen extends StatefulWidget {
  const EditProductScreen({super.key, required this.product});
  final ProductModel product;
  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _productRepository = ProductRepository();
  late final TextEditingController _nameController,_unitController,_purchaseController,_extraCostsController,_sellingController,_quantityController,_thresholdController,_barcodeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _unitController = TextEditingController(text: widget.product.unit);
    _purchaseController = TextEditingController(text: widget.product.purchasePrice.toString());
    _extraCostsController = TextEditingController(text: widget.product.extraCosts.toString());
    _sellingController = TextEditingController(text: widget.product.sellingPrice.toString());
    _quantityController = TextEditingController(text: widget.product.stockQty.toString());
    _thresholdController = TextEditingController(text: widget.product.lowStockThreshold.toString());
    _barcodeController = TextEditingController(text: widget.product.barcode ?? '');
  }
  @override
  void dispose() { _nameController.dispose(); _unitController.dispose(); _purchaseController.dispose(); _extraCostsController.dispose(); _sellingController.dispose(); _quantityController.dispose(); _thresholdController.dispose(); _barcodeController.dispose(); super.dispose(); }

  Future<void> _update() async {
    final copy = AppCopy.of(context);
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final purchasePrice = _toDouble(_purchaseController.text), extraCosts = _toDouble(_extraCostsController.text), stockQty = _toInt(_quantityController.text);
    final hasAccountingSensitiveChange = purchasePrice != widget.product.purchasePrice || extraCosts != widget.product.extraCosts || stockQty != widget.product.stockQty;
    if (hasAccountingSensitiveChange) { AppMessages.error(context, copy.t('editBlockedAccounting')); return; }
    setState(() => _isSaving = true);
    try {
      final businessId = AuthRepository.instance.currentUser?.businessId ?? AuthRepository.fallbackBusinessId;
      final product = widget.product.copyWith(name: _nameController.text.trim(), unit: _unitController.text.trim(), purchasePrice: purchasePrice, extraCosts: extraCosts, sellingPrice: _toDouble(_sellingController.text), stockQty: stockQty, lowStockThreshold: _toInt(_thresholdController.text), barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim());
      await _productRepository.updateProduct(businessId, product);
      if (!mounted) return;
      AppMessages.success(context, copy.t('updateProductSuccess'));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('updateProductError')}\n$error');
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  double _toDouble(String value) => double.tryParse(value.trim()) ?? 0.0;
  int _toInt(String value) => int.tryParse(value.trim()) ?? 0;
  String? _required(String? value, String field) { if (value == null || value.trim().isEmpty) return AppCopy.of(context).requiredField(field); return null; }
  String? _validateNumber(String? value, String field, {bool integer = false}) {
    final copy = AppCopy.of(context);
    if (value == null || value.trim().isEmpty) return copy.requiredField(field);
    final text = value.trim(); final isValid = integer ? int.tryParse(text) != null : double.tryParse(text) != null;
    if (!isValid) return copy.t('fieldInvalid').replaceAll('{field}', field);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('editProductTitle'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(controller: _nameController, decoration: InputDecoration(labelText: copy.t('productName')), validator: (value) => _required(value, copy.t('productName'))),
            const SizedBox(height: 12),
            TextFormField(controller: _unitController, decoration: InputDecoration(labelText: copy.t('unit')), validator: (value) => _required(value, copy.t('unit'))),
            const SizedBox(height: 12),
            TextFormField(controller: _purchaseController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: copy.t('purchasePrice')), validator: (value) => _validateNumber(value, copy.t('purchasePrice'))),
            const SizedBox(height: 12),
            TextFormField(controller: _extraCostsController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: copy.t('extraCosts')), validator: (value) => _validateNumber(value, copy.t('extraCosts'))),
            const SizedBox(height: 12),
            TextFormField(controller: _sellingController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: copy.t('sellingPrice')), validator: (value) => _validateNumber(value, copy.t('sellingPrice'))),
            const SizedBox(height: 12),
            TextFormField(controller: _quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: copy.t('quantity')), validator: (value) => _validateNumber(value, copy.t('quantity'), integer: true)),
            const SizedBox(height: 12),
            TextFormField(controller: _thresholdController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: copy.t('lowStockThreshold')), validator: (value) => _validateNumber(value, copy.t('lowStockThreshold'), integer: true)),
            const SizedBox(height: 12),
            TextFormField(controller: _barcodeController, decoration: InputDecoration(labelText: copy.t('barcode'))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Text(copy.t('editWarning'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _update,
              child: Text(_isSaving ? copy.t('saving') : copy.t('saveChanges')),
            ),
          ],
        ),
      ),
    );
  }
}
