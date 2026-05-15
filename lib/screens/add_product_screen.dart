import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_copy.dart';
import '../core/app_theme.dart';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';
import '../data/services/auth_service.dart';
import '../widgets/premium/premium_card.dart';
import '../widgets/premium/premium_field.dart';
import '../widgets/premium/premium_stat.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? product; // If provided, we are editing

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  int _activeSection = 0;
  bool _isSaving = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _extraCostsController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockQtyController;
  late TextEditingController _lowStockController;
  late TextEditingController _barcodeController;
  late TextEditingController _skuController;
  late TextEditingController _categoryController;
  late TextEditingController _brandController;
  late TextEditingController _supplierController;
  late TextEditingController _descriptionController;
  late TextEditingController _wholesalePriceController;
  late TextEditingController _discountPriceController;
  late TextEditingController _vatController;
  late TextEditingController _minStockController;
  late TextEditingController _maxStockController;
  late TextEditingController _warehouseController;
  late TextEditingController _shelfController;
  late TextEditingController _colorController;
  late TextEditingController _sizeController;
  late TextEditingController _weightController;
  late TextEditingController _dimensionsController;
  late TextEditingController _materialController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  late TextEditingController _originController;
  late TextEditingController _internalNotesController;

  // State flags
  String _status = 'active';
  bool _isSellable = true;
  bool _isDiscountAllowed = true;
  bool _isTrackingEnabled = true;
  bool _showInReports = true;
  bool _requiresSerial = false;
  bool _requiresExpiry = false;
  bool _isFeatured = false;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _unitController = TextEditingController(text: p?.unit ?? '');
    _purchasePriceController = TextEditingController(text: p?.purchasePrice.toString() ?? '0.0');
    _extraCostsController = TextEditingController(text: p?.extraCosts.toString() ?? '0.0');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice.toString() ?? '0.0');
    _stockQtyController = TextEditingController(text: p?.stockQty.toString() ?? '0');
    _lowStockController = TextEditingController(text: p?.lowStockThreshold.toString() ?? '5');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _supplierController = TextEditingController(text: p?.supplier ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _wholesalePriceController = TextEditingController(text: p?.wholesalePrice.toString() ?? '0.0');
    _discountPriceController = TextEditingController(text: p?.discountPrice.toString() ?? '0.0');
    _vatController = TextEditingController(text: p?.vatPercentage.toString() ?? '0.0');
    _minStockController = TextEditingController(text: p?.minStockAlert.toString() ?? '5');
    _maxStockController = TextEditingController(text: p?.maxStock.toString() ?? '999999');
    _warehouseController = TextEditingController(text: p?.warehouse ?? '');
    _shelfController = TextEditingController(text: p?.shelfLocation ?? '');
    _colorController = TextEditingController(text: p?.color ?? '');
    _sizeController = TextEditingController(text: p?.size ?? '');
    _weightController = TextEditingController(text: p?.weight.toString() ?? '0.0');
    _dimensionsController = TextEditingController(text: p?.dimensions ?? '');
    _materialController = TextEditingController(text: p?.material ?? '');
    _modelController = TextEditingController(text: p?.modelNumber ?? '');
    _serialController = TextEditingController(text: p?.serialNumber ?? '');
    _originController = TextEditingController(text: p?.originCountry ?? '');
    _internalNotesController = TextEditingController(text: p?.internalNotes ?? '');

    _status = p?.status ?? 'active';
    _isSellable = p?.isSellable ?? true;
    _isDiscountAllowed = p?.isDiscountAllowed ?? true;
    _isTrackingEnabled = p?.isTrackingEnabled ?? true;
    _showInReports = p?.showInReports ?? true;
    _requiresSerial = p?.requiresSerial ?? false;
    _requiresExpiry = p?.requiresExpiry ?? false;
    _isFeatured = p?.isFeatured ?? false;
    _isHidden = p?.isHidden ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _extraCostsController.dispose();
    _sellingPriceController.dispose();
    _stockQtyController.dispose();
    _lowStockController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _supplierController.dispose();
    _descriptionController.dispose();
    _wholesalePriceController.dispose();
    _discountPriceController.dispose();
    _vatController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _warehouseController.dispose();
    _shelfController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _materialController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _originController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  double get _purchasePrice => double.tryParse(_purchasePriceController.text) ?? 0.0;
  double get _extraCosts => double.tryParse(_extraCostsController.text) ?? 0.0;
  double get _sellingPrice => double.tryParse(_sellingPriceController.text) ?? 0.0;
  double get _landedCost => _purchasePrice + _extraCosts;
  double get _netProfit => _sellingPrice - _landedCost;
  double get _margin => _landedCost > 0 ? (_netProfit / _landedCost) * 100 : 0.0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final copy = AppCopy.of(context);
    final businessId = Provider.of<AuthService>(context, listen: false).currentUser?.uid ?? '';

    try {
      final product = ProductModel(
        id: widget.product?.id ?? 'p-${DateTime.now().microsecondsSinceEpoch}',
        businessId: businessId,
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        purchasePrice: _purchasePrice,
        extraCosts: _extraCosts,
        sellingPrice: _sellingPrice,
        stockQty: int.tryParse(_stockQtyController.text) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockController.text) ?? 5,
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0.0,
        discountPrice: double.tryParse(_discountPriceController.text) ?? 0.0,
        vatPercentage: double.tryParse(_vatController.text) ?? 0.0,
        minStockAlert: int.tryParse(_minStockController.text) ?? 5,
        maxStock: int.tryParse(_maxStockController.text) ?? 999999,
        warehouse: _warehouseController.text.trim().isEmpty ? null : _warehouseController.text.trim(),
        shelfLocation: _shelfController.text.trim().isEmpty ? null : _shelfController.text.trim(),
        status: _status,
        color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
        size: _sizeController.text.trim().isEmpty ? null : _sizeController.text.trim(),
        weight: double.tryParse(_weightController.text) ?? 0.0,
        dimensions: _dimensionsController.text.trim().isEmpty ? null : _dimensionsController.text.trim(),
        material: _materialController.text.trim().isEmpty ? null : _materialController.text.trim(),
        modelNumber: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        originCountry: _originController.text.trim().isEmpty ? null : _originController.text.trim(),
        internalNotes: _internalNotesController.text.trim().isEmpty ? null : _internalNotesController.text.trim(),
        isSellable: _isSellable,
        isDiscountAllowed: _isDiscountAllowed,
        isTrackingEnabled: _isTrackingEnabled,
        showInReports: _showInReports,
        requiresSerial: _requiresSerial,
        requiresExpiry: _requiresExpiry,
        isFeatured: _isFeatured,
        isHidden: _isHidden,
        updatedAt: DateTime.now(),
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );

      final repo = Provider.of<ProductRepository>(context, listen: false);
      if (widget.product == null) {
        await repo.addProduct(businessId, product);
      } else {
        await repo.updateProduct(businessId, product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy.t(widget.product == null ? 'saveSuccessProduct' : 'updateProductSuccess'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${copy.t('saveErrorProduct')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.background : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(copy.t(widget.product == null ? 'addProductTitle' : 'editProductTitle')),
        actions: [
          if (!isDesktop)
            IconButton(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          children: [
            // Sidebar Navigation
            if (isDesktop || isTablet) _buildSidebar(copy, isDark),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isDesktop && !isTablet) _buildMobileTabs(copy, isDark),
                        const SizedBox(height: 24),
                        _buildActiveSection(copy, isDark),
                        const SizedBox(height: 40),
                        if (isDesktop || isTablet)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    copy.t(widget.product == null ? 'saveProduct' : 'updateProduct'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Preview Panel
            if (isDesktop) _buildPreviewPanel(copy, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(AppCopy copy, bool isDark) {
    final sections = [
      {'icon': Icons.info_outline, 'label': copy.t('basicDetails')},
      {'icon': Icons.payments_outlined, 'label': copy.t('pricing')},
      {'icon': Icons.inventory_2_outlined, 'label': copy.t('inventory')},
      {'icon': Icons.straighten_outlined, 'label': copy.t('attributes')},
      {'icon': Icons.settings_outlined, 'label': copy.t('productSettings')},
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: isDark ? AppTheme.outlineDark : AppTheme.outlineLight,
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final isActive = _activeSection == index;
          return InkWell(
            onTap: () => setState(() => _activeSection = index),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isActive 
                  ? AppTheme.accent.withValues(alpha: 0.1) 
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    sections[index]['icon'] as IconData,
                    color: isActive ? AppTheme.accent : (isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    sections[index]['label'] as String,
                    style: TextStyle(
                      color: isActive ? AppTheme.accent : (isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileTabs(AppCopy copy, bool isDark) {
    final sections = [
      Icons.info_outline,
      Icons.payments_outlined,
      Icons.inventory_2_outlined,
      Icons.straighten_outlined,
      Icons.settings_outlined,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(sections.length, (index) {
          final isActive = _activeSection == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Icon(sections[index], size: 20),
              selected: isActive,
              onSelected: (_) => setState(() => _activeSection = index),
              selectedColor: AppTheme.accent,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(color: isActive ? Colors.white : (isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
              backgroundColor: isDark ? AppTheme.surfaceAlt : AppTheme.lightSurfaceMuted,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveSection(AppCopy copy, bool isDark) {
    switch (_activeSection) {
      case 0: return _buildBasicInfo(copy, isDark);
      case 1: return _buildPricingInfo(copy, isDark);
      case 2: return _buildInventoryInfo(copy, isDark);
      case 3: return _buildAttributesInfo(copy, isDark);
      case 4: return _buildSettingsInfo(copy, isDark);
      default: return const SizedBox();
    }
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBasicInfo(AppCopy copy, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(copy.t('basicInfo'), copy.t('overviewSubtitle'), isDark),
        PremiumCard(
          child: Column(
            children: [
              PremiumTextField(
                label: copy.t('productName'),
                controller: _nameController,
                isRequired: true,
                prefixIcon: Icons.shopping_bag_outlined,
                validator: (v) => v == null || v.isEmpty ? copy.requiredField(copy.t('productName')) : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('unit'),
                      controller: _unitController,
                      isRequired: true,
                      hint: 'kg, pcs, box...',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('sku'),
                      controller: _skuController,
                      hint: 'PROD-001',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('barcode'),
                controller: _barcodeController,
                prefixIcon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('category'),
                      controller: _categoryController,
                      prefixIcon: Icons.category_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('brand'),
                      controller: _brandController,
                      prefixIcon: Icons.branding_watermark_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('description'),
                controller: _descriptionController,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingInfo(AppCopy copy, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(copy.t('pricing'), copy.t('pricingSubtitle'), isDark),
        PremiumCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('purchasePrice'),
                      controller: _purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.input_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('extraCosts'),
                      controller: _extraCostsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.add_circle_outline_rounded,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('sellingPrice'),
                controller: _sellingPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.sell_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('wholesalePrice'),
                      controller: _wholesalePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('discountPrice'),
                      controller: _discountPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('vatPercentage'),
                controller: _vatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.percent_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryInfo(AppCopy copy, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(copy.t('inventory'), copy.t('inventorySubtitle'), isDark),
        PremiumCard(
          child: Column(
            children: [
              PremiumTextField(
                label: copy.t('currentQuantity'),
                controller: _stockQtyController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.inventory_rounded,
                readOnly: widget.product != null, // Use adjustment flow for editing stock
                hint: widget.product != null ? copy.t('editWarning') : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('minStockAlert'),
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('maxStock'),
                      controller: _maxStockController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('warehouse'),
                      controller: _warehouseController,
                      prefixIcon: Icons.warehouse_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('shelfLocation'),
                      controller: _shelfController,
                      prefixIcon: Icons.place_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttributesInfo(AppCopy copy, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(copy.t('attributes'), copy.t('attributesSubtitle'), isDark),
        PremiumCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('color'),
                      controller: _colorController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('size'),
                      controller: _sizeController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('weight'),
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('dimensions'),
                      controller: _dimensionsController,
                      hint: '10x20x30',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('material'),
                controller: _materialController,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('modelNumber'),
                      controller: _modelController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumTextField(
                      label: copy.t('serialNumber'),
                      controller: _serialController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('originCountry'),
                controller: _originController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsInfo(AppCopy copy, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(copy.t('productSettings'), copy.t('settingsSubtitle'), isDark),
        PremiumCard(
          child: Column(
            children: [
              _buildDropdown(
                label: copy.t('status'),
                value: _status,
                items: [
                  {'value': 'active', 'label': copy.t('statusActive')},
                  {'value': 'draft', 'label': copy.t('statusDraft')},
                  {'value': 'archived', 'label': copy.t('statusArchived')},
                ],
                onChanged: (v) => setState(() => _status = v!),
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSwitchTile(
                title: copy.t('isSellable'),
                value: _isSellable,
                onChanged: (v) => setState(() => _isSellable = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('isTrackingEnabled'),
                value: _isTrackingEnabled,
                onChanged: (v) => setState(() => _isTrackingEnabled = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('isDiscountAllowed'),
                value: _isDiscountAllowed,
                onChanged: (v) => setState(() => _isDiscountAllowed = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('showInReports'),
                value: _showInReports,
                onChanged: (v) => setState(() => _showInReports = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('requiresSerial'),
                value: _requiresSerial,
                onChanged: (v) => setState(() => _requiresSerial = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('requiresExpiry'),
                value: _requiresExpiry,
                onChanged: (v) => setState(() => _requiresExpiry = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('isFeatured'),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: copy.t('isHidden'),
                value: _isHidden,
                onChanged: (v) => setState(() => _isHidden = v),
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              PremiumTextField(
                label: copy.t('internalNotes'),
                controller: _internalNotesController,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceAlt : AppTheme.lightSurfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isDark ? AppTheme.outlineDark : AppTheme.outlineLight,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? AppTheme.surfaceAlt : AppTheme.lightSurface,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
              ),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item['value'],
                  child: Text(item['label']!),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required void Function(bool) onChanged,
    required bool isDark,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppTheme.accent,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildPreviewPanel(AppCopy copy, bool isDark) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? AppTheme.outlineDark : AppTheme.outlineLight,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.t('productPreview'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceMuted : AppTheme.lightSurfaceMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nameController.text.isEmpty ? copy.t('productName') : _nameController.text,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_categoryController.text} • ${_brandController.text}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _sellingPrice.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _unitController.text,
                        style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              copy.t('profitCalculation'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            PremiumStat(
              label: copy.t('landedCost'),
              value: _landedCost.toStringAsFixed(2),
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            PremiumStat(
              label: copy.t('netProfit'),
              value: _netProfit.toStringAsFixed(2),
              icon: Icons.trending_up_rounded,
              color: _netProfit >= 0 ? AppTheme.success : AppTheme.danger,
              trend: '${_margin.toStringAsFixed(1)}%',
              trendPositive: _netProfit >= 0,
            ),
            const SizedBox(height: 24),
            Text(
              copy.t('stockHealth'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHealthIndicator(copy, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(AppCopy copy, bool isDark) {
    final qty = int.tryParse(_stockQtyController.text) ?? 0;
    final low = int.tryParse(_lowStockController.text) ?? 5;
    
    String label = copy.t('stable');
    Color color = AppTheme.success;
    double progress = (qty / (low * 2)).clamp(0, 1);

    if (qty <= 0) {
      label = copy.t('outOfStock');
      color = AppTheme.danger;
    } else if (qty <= low) {
      label = copy.t('lowStock');
      color = AppTheme.warning;
    }

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              Text('$qty / ${low * 2}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? AppTheme.surfaceMuted : AppTheme.lightSurfaceMuted,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
