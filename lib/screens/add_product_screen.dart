import 'package:flutter/material.dart';

import '../../data/database/database_helper.dart';
import '../../data/models/product_model.dart';
import '../data/repositories/business_profile_repository.dart';
import '../core/app_copy.dart';
import '../core/app_messages.dart';
import '../data/repositories/product_repository.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _productRepository = ProductRepository();
  final BusinessProfileRepository _businessRepository = BusinessProfileRepository();

  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _extraCostsController = TextEditingController(text: '0');
  final _sellingController = TextEditingController();
  final _quantityController = TextEditingController();
  final _thresholdController = TextEditingController(text: '5');
  final _barcodeController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _purchaseController.dispose();
    _extraCostsController.dispose();
    _sellingController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final copy = AppCopy.of(context);
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final business = await _businessRepository.getBusinessProfile();
      final businessId = business?.id ?? '1';

      final product = ProductModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        businessId: businessId,
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        purchasePrice: _toDouble(_purchaseController.text),
        extraCosts: _toDouble(_extraCostsController.text),
        sellingPrice: _toDouble(_sellingController.text),
        stockQty: _toInt(_quantityController.text),
        lowStockThreshold: _toInt(_thresholdController.text),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
      );

      await _productRepository.addProduct(product);

      await DBHelper.addJournalEntry(
        debitId: 2,
        creditId: 3,
        amount: product.totalStockValue,
        desc: copy.isEnglish
            ? 'Add opening balance for product ${product.name}'
            : 'إضافة رصيد افتتاحي للصنف ${product.name}',
      );

      if (!mounted) return;

      _clear();
      AppMessages.success(context, copy.t('saveSuccessProduct'));
    } catch (error) {
      if (!mounted) return;
      AppMessages.error(context, '${copy.t('saveErrorProduct')}\n$error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clear() {
    _nameController.clear();
    _unitController.clear();
    _purchaseController.clear();
    _extraCostsController.text = '0';
    _sellingController.clear();
    _quantityController.clear();
    _thresholdController.text = '5';
    _barcodeController.clear();
  }

  double _toDouble(String value) => double.tryParse(value.trim()) ?? 0.0;

  int _toInt(String value) => int.tryParse(value.trim()) ?? 0;

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return AppCopy.of(context).requiredField(field);
    }
    return null;
  }

  String? _validateNumber(String? value, String field) {
    final copy = AppCopy.of(context);
    if (value == null || value.trim().isEmpty) {
      return copy.requiredField(field);
    }
    if (double.tryParse(value) == null) {
      return copy.t('invalidValue');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.t('addProductTitle'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: copy.t('productName')),
              validator: (v) => _required(v, copy.t('productName')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitController,
              decoration: InputDecoration(labelText: copy.t('unit')),
              validator: (v) => _required(v, copy.t('unit')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchaseController,
              decoration: InputDecoration(labelText: copy.t('purchasePrice')),
              validator: (v) => _validateNumber(v, copy.t('purchasePrice')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellingController,
              decoration: InputDecoration(labelText: copy.t('sellingPrice')),
              validator: (v) => _validateNumber(v, copy.t('sellingPrice')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: copy.t('quantity')),
              validator: (v) => _validateNumber(v, copy.t('quantity')),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: Text(copy.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
