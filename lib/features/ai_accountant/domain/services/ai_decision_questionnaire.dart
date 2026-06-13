enum AiDecisionInputField {
  quantity,
  unitCost,
  expectedSellingPrice,
  currentPrice,
  proposedPrice,
  demandEvidence,
  customerPaymentHistory,
  paymentTerms,
  importCosts,
  timing,
}

class AiDecisionQuestionnaireState {
  final String sessionId;
  final String decisionType;
  final Map<AiDecisionInputField, dynamic> collectedInputs;
  final List<AiDecisionInputField> requiredInputs;
  final DateTime updatedAt;

  const AiDecisionQuestionnaireState({
    required this.sessionId,
    required this.decisionType,
    required this.collectedInputs,
    required this.requiredInputs,
    required this.updatedAt,
  });

  AiDecisionInputField? get nextMissingInput {
    for (final field in requiredInputs) {
      if (!collectedInputs.containsKey(field)) return field;
    }
    return null;
  }

  bool get isComplete => nextMissingInput == null;

  AiDecisionQuestionnaireState copyWith({
    String? decisionType,
    Map<AiDecisionInputField, dynamic>? collectedInputs,
    List<AiDecisionInputField>? requiredInputs,
    DateTime? updatedAt,
  }) {
    return AiDecisionQuestionnaireState(
      sessionId: sessionId,
      decisionType: decisionType ?? this.decisionType,
      collectedInputs: collectedInputs ?? this.collectedInputs,
      requiredInputs: requiredInputs ?? this.requiredInputs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AiDecisionQuestionnaire {
  AiDecisionQuestionnaireState? _activeState;

  AiDecisionQuestionnaireState? get activeState => _activeState;

  void clear() {
    _activeState = null;
  }

  AiDecisionQuestionnaireState start({
    required String decisionType,
    required List<AiDecisionInputField> requiredInputs,
    Map<AiDecisionInputField, dynamic> seedInputs = const {},
  }) {
    _activeState = AiDecisionQuestionnaireState(
      sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
      decisionType: decisionType,
      collectedInputs: Map<AiDecisionInputField, dynamic>.from(seedInputs),
      requiredInputs: requiredInputs,
      updatedAt: DateTime.now(),
    );
    return _activeState!;
  }

  AiDecisionQuestionnaireState? continueWith(String userText) {
    final state = _activeState;
    if (state == null || state.isComplete) return state;

    final field = state.nextMissingInput;
    if (field == null) return state;

    final parsed = _parseAnswer(userText, field);
    if (parsed == null) return state;

    final collected = Map<AiDecisionInputField, dynamic>.from(
      state.collectedInputs,
    );
    collected[field] = parsed;
    _activeState = state.copyWith(
      collectedInputs: collected,
      updatedAt: DateTime.now(),
    );
    return _activeState;
  }

  String questionFor(AiDecisionInputField field) {
    switch (field) {
      case AiDecisionInputField.quantity:
        return 'What quantity are you considering?';
      case AiDecisionInputField.unitCost:
        return 'What is the purchase cost per unit or carton?';
      case AiDecisionInputField.expectedSellingPrice:
        return 'What is the expected selling price per unit or carton?';
      case AiDecisionInputField.currentPrice:
        return 'What is the current selling price?';
      case AiDecisionInputField.proposedPrice:
        return 'What new price are you considering?';
      case AiDecisionInputField.demandEvidence:
        return 'What evidence do you have that demand can absorb this decision?';
      case AiDecisionInputField.customerPaymentHistory:
        return 'What is this customer payment history: reliable, delayed, or unknown?';
      case AiDecisionInputField.paymentTerms:
        return 'Will this be cash or credit, and what payment term?';
      case AiDecisionInputField.importCosts:
        return 'What are the shipping, customs, and import costs?';
      case AiDecisionInputField.timing:
        return 'When would this decision happen: now or later?';
    }
  }

  dynamic _parseAnswer(String userText, AiDecisionInputField field) {
    final normalized = userText.toLowerCase().trim();
    final number = _firstNumber(normalized);
    switch (field) {
      case AiDecisionInputField.quantity:
      case AiDecisionInputField.unitCost:
      case AiDecisionInputField.expectedSellingPrice:
      case AiDecisionInputField.currentPrice:
      case AiDecisionInputField.proposedPrice:
      case AiDecisionInputField.importCosts:
        return number != null && number > 0 ? number : null;
      case AiDecisionInputField.demandEvidence:
      case AiDecisionInputField.customerPaymentHistory:
      case AiDecisionInputField.paymentTerms:
      case AiDecisionInputField.timing:
        return normalized.isEmpty ? null : userText.trim();
    }
  }

  double? _firstNumber(String text) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }
}
