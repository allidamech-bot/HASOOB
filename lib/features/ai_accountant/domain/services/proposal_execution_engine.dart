import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../data/database/database_helper.dart';
import '../../data/models/ai_proposal_model.dart';

class ProposalExecutionEngine {
  ProposalExecutionEngine({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Future<ProposalExecutionResult> executeProposal({
    required AiProposalModel proposal,
    required String businessId,
  }) async {
    try {
      if (proposal.actionType == 'tool_response') {
        final toolResult =
            proposal.inventoryPayload?['toolResult'] as Map<String, dynamic>?;
        if (toolResult == null) {
          return const ProposalExecutionResult(
            success: false,
            error: 'No tool result in proposal.',
          );
        }
        final auditStored = await _tryStoreAuditLog(
          businessId,
          proposal,
          {'toolResult': toolResult},
        );
        return ProposalExecutionResult(
          success: true,
          data: {
            'toolResult': toolResult,
            'auditLog': {'status': auditStored ? 'stored' : 'failed'}
          },
          message: 'تم تنفيذ الاستعلام المالي بنجاح.',
        );
      }

      if (proposal.actionType == 'pricing_simulation') {
        final data = await DBHelper.saveAiPricingSimulation(
          businessId: businessId,
          pricingPayload: proposal.pricingPayload ?? {},
        );
        final auditStored = await _tryStoreAuditLog(businessId, proposal, data);
        return ProposalExecutionResult(
          success: true,
          message: 'تم حفظ محاكاة التسعير.',
          data: {
            ...data,
            'auditLog': {'status': auditStored ? 'stored' : 'failed'}
          },
        );
      }

      if (proposal.actionType == 'purchase') {
        return await _executePurchase(proposal, businessId);
      }

      if (proposal.actionType == 'sale') {
        return await _executeSale(proposal, businessId);
      }

      return ProposalExecutionResult(
        success: false,
        error: 'Unsupported action type: ${proposal.actionType}',
      );
    } catch (e) {
      debugPrint('[ProposalExecutionEngine] Error: $e');
      return ProposalExecutionResult(
        success: false,
        error: 'Execution failed safely before completion: $e',
      );
    }
  }

  Future<ProposalExecutionResult> _executePurchase(
    AiProposalModel proposal,
    String businessId,
  ) async {
    final accountGuard = await _guardRequiredAccounts('purchase', businessId);
    if (accountGuard != null) return accountGuard;

    final inventory = proposal.inventoryPayload;
    if (inventory == null) {
      return const ProposalExecutionResult(
        success: false,
        error: 'Missing inventory payload for purchase.',
      );
    }

    final quantity = _toInt(inventory['quantity']);
    final costPrice = _toDouble(inventory['costPrice']);
    if (quantity <= 0 || costPrice < 0) {
      return const ProposalExecutionResult(
        success: false,
        error: 'Invalid purchase quantity or cost.',
      );
    }

    final productName = inventory['name']?.toString().trim() ?? '';
    final explicitProductId = _firstNonEmpty([
      inventory['productId'],
      inventory['id'],
    ]);

    final match = await DBHelper.resolveAiProductMatch(
      businessId: businessId,
      productId: explicitProductId,
      productName: productName,
    );

    final canCreateFromExplicitId =
        explicitProductId != null && match['status'] == 'product_id_not_found';
    if (match['status'] != 'matched' && !canCreateFromExplicitId) {
      return ProposalExecutionResult(
        success: false,
        requiresUserConfirmation: true,
        error:
            'يلزم تأكيد الصنف قبل تنفيذ قيد الشراء. لم يتم إجراء أي تعديل على البيانات.',
        data: match,
      );
    }

    final matchedProduct = match['product'] as Map<String, dynamic>?;
    final resolvedProductId =
        explicitProductId ?? matchedProduct?['id']?.toString() ?? '';
    final resolvedProductName = productName.isNotEmpty
        ? productName
        : matchedProduct?['name']?.toString() ?? resolvedProductId;
    if (resolvedProductId.isEmpty || resolvedProductName.isEmpty) {
      return const ProposalExecutionResult(
        success: false,
        requiresUserConfirmation: true,
        error: 'Product identity is incomplete.',
      );
    }

    final data = await DBHelper.executeAiPurchase(
      businessId: businessId,
      productId: resolvedProductId,
      productName: resolvedProductName,
      quantity: quantity,
      costPrice: costPrice,
      explanation: proposal.explanation,
      matchMetadata: Map<String, dynamic>.from(match),
    );
    final auditStored = await _tryStoreAuditLog(businessId, proposal, data);

    return ProposalExecutionResult(
      success: true,
      message: 'تم تنفيذ قيد الشراء بأمان.',
      data: {
        ...data,
        'auditLog': {'status': auditStored ? 'stored' : 'failed'}
      },
    );
  }

  Future<ProposalExecutionResult> _executeSale(
    AiProposalModel proposal,
    String businessId,
  ) async {
    final accountGuard = await _guardRequiredAccounts('sale', businessId);
    if (accountGuard != null) return accountGuard;

    final financial = proposal.financialPayload;
    if (financial == null) {
      return const ProposalExecutionResult(
        success: false,
        error: 'Missing financial payload for sale.',
      );
    }

    final inventory = proposal.inventoryPayload ?? {};
    final quantity = _toInt(inventory['quantity'] ?? 1);
    final totalAmount = _toDouble(financial['totalAmount']);
    final explicitUnitPrice = _toDouble(financial['unitPrice']);
    final unitPrice =
        explicitUnitPrice > 0 ? explicitUnitPrice : totalAmount / quantity;
    if (quantity <= 0 || totalAmount <= 0 || unitPrice <= 0) {
      return const ProposalExecutionResult(
        success: false,
        error: 'Invalid sale quantity or amount.',
      );
    }

    final productName = inventory['name']?.toString().trim() ?? '';
    final explicitProductId = _firstNonEmpty([
      inventory['productId'],
      inventory['id'],
    ]);
    final match = await DBHelper.resolveAiProductMatch(
      businessId: businessId,
      productId: explicitProductId,
      productName: productName,
    );
    if (match['status'] != 'matched') {
      return ProposalExecutionResult(
        success: false,
        requiresUserConfirmation: true,
        error:
            'يلزم تأكيد الصنف قبل تنفيذ فاتورة البيع. لم يتم إجراء أي تعديل على البيانات.',
        data: match,
      );
    }

    final product = match['product'] as Map<String, dynamic>;
    final data = await DBHelper.executeAiSale(
      businessId: businessId,
      productId: product['id'].toString(),
      quantity: quantity,
      unitPrice: unitPrice,
      explanation: proposal.explanation,
      customerId: proposal.customerPayload?['id']?.toString(),
      customerName: proposal.customerPayload?['name']?.toString(),
      matchMetadata: Map<String, dynamic>.from(match),
    );
    final auditStored = await _tryStoreAuditLog(businessId, proposal, data);

    return ProposalExecutionResult(
      success: true,
      message: 'تم إنشاء فاتورة البيع والقيد المحاسبي.',
      data: {
        ...data,
        'auditLog': {'status': auditStored ? 'stored' : 'failed'}
      },
    );
  }

  Future<bool> _tryStoreAuditLog(
    String businessId,
    AiProposalModel proposal,
    Map<String, dynamic> resultData,
  ) async {
    try {
      final firestore = _firestore ?? FirebaseFirestore.instance;
      await firestore.collection('ai_audit_logs').add({
        'businessId': businessId,
        'timestamp': FieldValue.serverTimestamp(),
        'proposal': proposal.toMap(),
        'result': resultData,
      });
      return true;
    } catch (e) {
      debugPrint('[ProposalExecutionEngine] Audit log failed: $e');
      return false;
    }
  }

  Future<ProposalExecutionResult?> _guardRequiredAccounts(
    String actionType,
    String businessId,
  ) async {
    final requiredCodes = DBHelper.aiRequiredAccountCodesFor(actionType);
    if (requiredCodes.isEmpty) return null;

    final missing = await DBHelper.missingAiAccountCodes(
      businessId,
      requiredCodes,
    );
    if (missing.isEmpty) return null;

    return ProposalExecutionResult(
      success: false,
      requiresUserConfirmation: true,
      error:
          'يلزم إكمال إعداد دليل الحسابات قبل تنفيذ هذا القيد. لم يتم إجراء أي تعديل على البيانات.',
      data: {
        'reason': 'missing_chart_accounts',
        'missingAccountCodes': missing,
      },
    );
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class ProposalExecutionResult {
  final bool success;
  final String? error;
  final String? message;
  final dynamic data;
  final bool requiresUserConfirmation;

  const ProposalExecutionResult({
    required this.success,
    this.error,
    this.message,
    this.data,
    this.requiresUserConfirmation = false,
  });

  bool get isSuccess => success && error == null;
}
