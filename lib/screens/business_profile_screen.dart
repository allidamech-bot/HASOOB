import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/business_model.dart';
import '../../data/repositories/business_profile_repository.dart';
import '../core/app_copy.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _repository = BusinessProfileRepository();
  final _businessNameController = TextEditingController();
  final _tradeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsAppController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _defaultInvoiceNotesController = TextEditingController();
  final _defaultQuotationNotesController = TextEditingController();
  final _paymentTermsController = TextEditingController();

  File? _logoFile;
  String? _logoPath;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _tradeNameController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _registrationNumberController.dispose();
    _defaultInvoiceNotesController.dispose();
    _defaultQuotationNotesController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _logoFile = File(picked.path);
        _logoPath = picked.path;
      });
    }
  }

  Future<void> _load() async {
    try {
      final data = await _repository.getBusinessProfile();
      if (data != null) {
        _businessNameController.text = data.name;
        _tradeNameController.text = data.tradeName ?? '';
        _phoneController.text = data.phone ?? '';
        _whatsAppController.text = data.whatsapp ?? '';
        _emailController.text = data.email ?? '';
        _addressController.text = data.address ?? '';
        _taxNumberController.text = data.taxNumber ?? '';
        _registrationNumberController.text = data.registrationNumber ?? '';
        _defaultInvoiceNotesController.text = data.defaultInvoiceNotes ?? '';
        _defaultQuotationNotesController.text = data.defaultQuotationNotes ?? '';
        _paymentTermsController.text = data.paymentTermsFooter ?? '';
        _logoPath = data.logoPath;

        if (_logoPath != null && _logoPath!.isNotEmpty) {
          final file = File(_logoPath!);
          if (await file.exists()) {
            _logoFile = file;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessages.error(context, '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await _repository.saveBusinessProfile(BusinessModel(
        id: '', // Handled by DB for profile
        name: _businessNameController.text.trim(),
        tradeName: _tradeNameController.text.trim(),
        logoPath: _logoPath ?? '',
        phone: _phoneController.text.trim(),
        whatsapp: _whatsAppController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim(),
        defaultInvoiceNotes: _defaultInvoiceNotesController.text.trim(),
        defaultQuotationNotes: _defaultQuotationNotesController.text.trim(),
        paymentTermsFooter: _paymentTermsController.text.trim(),
        ownerId: '',
        createdAt: DateTime.now(),
      ));

      if (!mounted) return;
      AppMessages.success(context, AppCopy.of(context).t('businessProfileSaved'));
    } catch (e) {
      if (!mounted) return;
      AppMessages.error(context, '$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      filled: true,
      fillColor: AppTheme.surfaceAltFor(context),
      labelStyle: TextStyle(
        color: AppTheme.textSecondaryFor(context),
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppTheme.accent,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: TextStyle(
        color: AppTheme.textSecondaryFor(context),
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppTheme.borderFor(context), width: 1.15),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.4),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppTheme.accent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLogoPicker(AppCopy copy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.t('logo'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltFor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderFor(context), width: 1.15),
            ),
            child: Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceFor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderFor(context)),
                  ),
                  child: _logoFile == null
                      ? Icon(
                          Icons.image_outlined,
                          size: 34,
                          color: AppTheme.textSecondaryFor(context),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _logoFile!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              size: 34,
                              color: AppTheme.textSecondaryFor(context),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.t('uploadBusinessLogo'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        copy.t('logoHelp'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryFor(context),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.upload_rounded),
                          label: Text(copy.businessLogoAction(_logoFile != null)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines > 1 ? minLines + 1 : 1,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
        decoration: _fieldDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      appBar: AppBar(
        title: Text(copy.t('businessProfileTitle')),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildSection(
                    title: copy.t('basicInfo'),
                    icon: Icons.business_rounded,
                    children: [
                      _field(_businessNameController, copy.t('businessName')),
                      _field(_tradeNameController, copy.t('tradeName')),
                      _buildLogoPicker(copy),
                    ],
                  ),
                  _buildSection(
                    title: copy.t('contactInfo'),
                    icon: Icons.call_rounded,
                    children: [
                      _field(_phoneController, copy.t('phone'),
                          keyboardType: TextInputType.phone),
                      _field(_whatsAppController, copy.t('whatsApp'),
                          keyboardType: TextInputType.phone),
                      _field(_emailController, copy.t('mail'),
                          keyboardType: TextInputType.emailAddress),
                      _field(
                        _addressController,
                        copy.t('address'),
                        minLines: 2,
                        keyboardType: TextInputType.streetAddress,
                      ),
                    ],
                  ),
                  _buildSection(
                    title: copy.t('officialInfo'),
                    icon: Icons.verified_user_rounded,
                    children: [
                      _field(_taxNumberController, copy.t('taxNumber')),
                      _field(_registrationNumberController, copy.t('registrationNumber')),
                    ],
                  ),
                  _buildSection(
                    title: copy.t('documentDefaults'),
                    icon: Icons.description_rounded,
                    children: [
                      _field(_defaultQuotationNotesController, copy.t('quotationNotes'),
                          minLines: 2),
                      _field(_defaultInvoiceNotesController, copy.t('invoiceNotes'),
                          minLines: 2),
                      _field(_paymentTermsController, copy.t('paymentTerms'),
                          minLines: 2),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(copy.t('save')),
                  ),
                ],
              ),
            ),
    );
  }
}
