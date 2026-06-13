import 'ai_data_collection_state.dart';
import 'ai_workflow_session.dart';

class AiWorkflowManager {
  AiWorkflowManager({this.timeout = const Duration(minutes: 30)});

  final Duration timeout;
  AiWorkflowSession? _activeSession;

  AiWorkflowSession? get activeSession {
    final session = _activeSession;
    if (session == null) return null;
    if (_isExpired(session)) {
      _activeSession = null;
      return null;
    }
    return _activeSession;
  }

  AiWorkflowTurnResult? handleMessage(String text, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final normalized = _normalized(text);
    if (_isCancel(normalized)) {
      _activeSession = null;
      return const AiWorkflowTurnResult(
        session: null,
        responseText: 'Workflow cancelled. Nothing was saved or executed.',
        isCancelled: true,
        suggestedReplies: [
          'Prepare a purchase',
          'Prepare a sale',
          'Analyze business',
        ],
      );
    }

    final session = activeSession;
    if (session != null) {
      return _continue(session, text, timestamp);
    }

    final type = _detectWorkflow(normalized);
    if (type == null) return null;
    return _start(type, timestamp);
  }

  AiWorkflowTurnResult startWorkflow(
    AiWorkflowType type, {
    DateTime? now,
  }) {
    return _start(type, now ?? DateTime.now());
  }

  void clear() {
    _activeSession = null;
  }

  AiWorkflowTurnResult _start(AiWorkflowType type, DateTime now) {
    final session = AiWorkflowSession(
      workflowId: 'wf-${now.microsecondsSinceEpoch}',
      workflowType: type,
      currentStep: 1,
      collectedData: const {},
      missingFields: _requiredFields(type),
      createdAt: now,
      updatedAt: now,
    );
    _activeSession = session;
    return AiWorkflowTurnResult(
      session: session,
      responseText: _questionFor(session),
      suggestedReplies: const ['Cancel'],
    );
  }

  AiWorkflowTurnResult _continue(
    AiWorkflowSession session,
    String text,
    DateTime now,
  ) {
    final field = session.waitingField;
    if (field == null) {
      _activeSession = null;
      return const AiWorkflowTurnResult(
        session: null,
        responseText: 'This workflow is already complete.',
      );
    }

    final value = _parseField(field, text);
    if (value == null) {
      return AiWorkflowTurnResult(
        session: session,
        responseText: _validationMessage(field),
        suggestedReplies: const ['Cancel'],
      );
    }

    final data = Map<String, dynamic>.from(session.collectedData);
    data[field] = value;
    final missing = session.missingFields.skip(1).toList();
    final updated = session.copyWith(
      collectedData: data,
      missingFields: missing,
      currentStep: data.length + 1,
      updatedAt: now,
    );

    if (missing.isEmpty) {
      _activeSession = null;
      return AiWorkflowTurnResult(
        session: updated,
        responseText: _completionText(updated),
        isComplete: true,
        proposalDraftText: _proposalDraft(updated),
        suggestedReplies: const ['Review proposal', 'Start another workflow'],
      );
    }

    _activeSession = updated;
    return AiWorkflowTurnResult(
      session: updated,
      responseText: _questionFor(updated),
      suggestedReplies: const ['Cancel'],
    );
  }

  List<String> _requiredFields(AiWorkflowType type) {
    switch (type) {
      case AiWorkflowType.purchase:
        return const [
          AiWorkflowField.product,
          AiWorkflowField.quantity,
          AiWorkflowField.cost,
        ];
      case AiWorkflowType.sale:
        return const [
          AiWorkflowField.product,
          AiWorkflowField.quantity,
          AiWorkflowField.customer,
          AiWorkflowField.sellingPrice,
        ];
      case AiWorkflowType.pricing:
        return const [
          AiWorkflowField.product,
          AiWorkflowField.cost,
          AiWorkflowField.sellingPrice,
        ];
      case AiWorkflowType.inventoryAdjustment:
        return const [
          AiWorkflowField.product,
          AiWorkflowField.adjustmentQuantity,
        ];
      case AiWorkflowType.customerBalanceInquiry:
        return const [AiWorkflowField.customer];
      case AiWorkflowType.supplierInquiry:
        return const [AiWorkflowField.supplier];
    }
  }

  String _questionFor(AiWorkflowSession session) {
    final field = session.waitingField;
    switch (field) {
      case AiWorkflowField.product:
        return 'What is the product name? / ما اسم المنتج؟';
      case AiWorkflowField.quantity:
        return 'How many units or cartons? / كم الكمية؟';
      case AiWorkflowField.cost:
        return 'What is the unit cost? / كم سعر الوحدة؟';
      case AiWorkflowField.sellingPrice:
        return 'What is the selling price? / كم سعر البيع؟';
      case AiWorkflowField.customer:
        return 'Who is the customer? / لمن تم البيع؟';
      case AiWorkflowField.supplier:
        return 'Who is the supplier? / من هو المورد؟';
      case AiWorkflowField.adjustmentQuantity:
        return 'What adjustment quantity should be reviewed? / كم كمية التعديل؟';
      default:
        return 'What detail should I record next?';
    }
  }

  Object? _parseField(String field, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    switch (field) {
      case AiWorkflowField.quantity:
      case AiWorkflowField.cost:
      case AiWorkflowField.sellingPrice:
      case AiWorkflowField.adjustmentQuantity:
        final value = _firstNumber(trimmed);
        if (value == null || value <= 0) return null;
        return value;
      default:
        return trimmed;
    }
  }

  String _validationMessage(String field) {
    switch (field) {
      case AiWorkflowField.quantity:
      case AiWorkflowField.adjustmentQuantity:
        return 'Please enter a quantity greater than zero.';
      case AiWorkflowField.cost:
        return 'Please enter a unit cost greater than zero.';
      case AiWorkflowField.sellingPrice:
        return 'Please enter a selling price greater than zero.';
      default:
        return 'Please provide a clear value for ${AiWorkflowField.label(field)}.';
    }
  }

  String _completionText(AiWorkflowSession session) {
    switch (session.workflowType) {
      case AiWorkflowType.purchase:
        return 'I collected the purchase details and prepared a purchase proposal for review. Nothing has been saved or executed.';
      case AiWorkflowType.sale:
        return 'I collected the sale details and prepared a sale proposal for review. Nothing has been saved or executed.';
      case AiWorkflowType.pricing:
        return 'I collected the pricing details and prepared a pricing analysis for review.';
      case AiWorkflowType.inventoryAdjustment:
        return 'I collected the inventory adjustment details for review. This still requires approval before any change.';
      case AiWorkflowType.customerBalanceInquiry:
        return 'I collected the customer name for a balance review.';
      case AiWorkflowType.supplierInquiry:
        return 'I collected the supplier name for review.';
    }
  }

  String? _proposalDraft(AiWorkflowSession session) {
    final data = session.collectedData;
    switch (session.workflowType) {
      case AiWorkflowType.purchase:
        return 'Prepare a purchase proposal for ${data[AiWorkflowField.quantity]} units of ${data[AiWorkflowField.product]} at unit cost ${data[AiWorkflowField.cost]}.';
      case AiWorkflowType.sale:
        return 'Prepare a sale proposal for ${data[AiWorkflowField.quantity]} units of ${data[AiWorkflowField.product]} to ${data[AiWorkflowField.customer]} at selling price ${data[AiWorkflowField.sellingPrice]}.';
      case AiWorkflowType.pricing:
        return 'Prepare a pricing simulation for ${data[AiWorkflowField.product]} with unit cost ${data[AiWorkflowField.cost]} and current selling price ${data[AiWorkflowField.sellingPrice]}.';
      case AiWorkflowType.inventoryAdjustment:
      case AiWorkflowType.customerBalanceInquiry:
      case AiWorkflowType.supplierInquiry:
        return null;
    }
  }

  AiWorkflowType? _detectWorkflow(String normalized) {
    if (_containsAny(normalized, [
      'prepare purchase',
      'purchase workflow',
      'i bought',
      'bought',
      'purchased',
      'buy',
      'اشتريت',
      'شراء',
    ])) {
      return AiWorkflowType.purchase;
    }
    if (_containsAny(normalized, [
      'prepare sale',
      'sale workflow',
      'i sold',
      'sold',
      'sale',
      'بعت',
      'بيع',
    ])) {
      return AiWorkflowType.sale;
    }
    if (_containsAny(normalized, [
      'pricing workflow',
      'price suitable',
      'pricing analysis',
      'سعر المنتج مناسب',
      'تسعير',
    ])) {
      return AiWorkflowType.pricing;
    }
    if (_containsAny(normalized, [
      'inventory adjustment',
      'adjust stock',
      'تعديل المخزون',
    ])) {
      return AiWorkflowType.inventoryAdjustment;
    }
    if (_containsAny(normalized, [
      'customer balance',
      'رصيد عميل',
    ])) {
      return AiWorkflowType.customerBalanceInquiry;
    }
    if (_containsAny(normalized, [
      'supplier',
      'مورد',
    ])) {
      return AiWorkflowType.supplierInquiry;
    }
    return null;
  }

  bool _isExpired(AiWorkflowSession session) {
    return DateTime.now().difference(session.updatedAt) > timeout;
  }

  bool _isCancel(String normalized) {
    return _containsAny(normalized, ['cancel', 'stop', 'إلغاء', 'الغاء']);
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  String _normalized(String value) => value.toLowerCase().trim();

  double? _firstNumber(String text) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }
}
