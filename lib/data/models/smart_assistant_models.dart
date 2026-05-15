import 'dart:convert';

enum SmartAssistantIntent {
  calculateProfit,
  calculateMargin,
  calculateTotalCost,
  calculateSaleTotal,
  calculateDiscount,
  calculateTax,
  calculateRemainingBalance,
  calculateUnitPrice,
  calculateWholesaleTotal,
  calculateStockValue,
  addProductDraft,
  updateStockDraft,
  createSaleDraft,
  createCustomerPaymentDraft,
  createExpenseDraft,
  createReminderDraft,
  inventoryValueQuery,
  lowStockQuery,
  customerBalancesQuery,
  monthlySalesQuery,
  monthlyExpensesQuery,
  bestSellingProductsQuery,
  mostProfitableProductsQuery,
  unknown,
}

enum SmartAssistantActionStatus {
  preview,
  saved,
  draftSaved,
  cancelled,
  failed,
}

class SmartAssistantField {
  const SmartAssistantField({
    required this.key,
    required this.label,
    required this.value,
    this.editable = true,
  });

  final String key;
  final String label;
  final Object? value;
  final bool editable;

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'value': value,
        'editable': editable,
      };

  factory SmartAssistantField.fromJson(Map<String, dynamic> json) {
    return SmartAssistantField(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: json['value'],
      editable: json['editable'] != false,
    );
  }
}

class SmartAssistantParseResult {
  const SmartAssistantParseResult({
    required this.userInput,
    required this.intent,
    required this.extracted,
    required this.missingFields,
    required this.warnings,
    required this.confidence,
    this.suggestedAction,
  });

  final String userInput;
  final SmartAssistantIntent intent;
  final Map<String, dynamic> extracted;
  final List<String> missingFields;
  final List<String> warnings;
  final double confidence;
  final Map<String, dynamic>? suggestedAction;

  bool get isReady =>
      missingFields.isEmpty && intent != SmartAssistantIntent.unknown;

  SmartAssistantParseResult copyWith({
    Map<String, dynamic>? extracted,
    List<String>? missingFields,
    List<String>? warnings,
    double? confidence,
    Map<String, dynamic>? suggestedAction,
  }) {
    return SmartAssistantParseResult(
      userInput: userInput,
      intent: intent,
      extracted: extracted ?? this.extracted,
      missingFields: missingFields ?? this.missingFields,
      warnings: warnings ?? this.warnings,
      confidence: confidence ?? this.confidence,
      suggestedAction: suggestedAction ?? this.suggestedAction,
    );
  }
}

class SmartCalculationResult {
  const SmartCalculationResult({
    required this.values,
    required this.summary,
    this.warnings = const [],
  });

  final Map<String, dynamic> values;
  final String summary;
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
        'values': values,
        'summary': summary,
        'warnings': warnings,
      };

  factory SmartCalculationResult.fromJson(Map<String, dynamic> json) {
    return SmartCalculationResult(
      values: Map<String, dynamic>.from(json['values'] as Map? ?? const {}),
      summary: json['summary']?.toString() ?? '',
      warnings: (json['warnings'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SmartAssistantPreview {
  const SmartAssistantPreview({
    required this.parse,
    required this.calculation,
    required this.fields,
  });

  final SmartAssistantParseResult parse;
  final SmartCalculationResult calculation;
  final List<SmartAssistantField> fields;
}

class SmartAssistantHistoryEntry {
  const SmartAssistantHistoryEntry({
    required this.id,
    required this.userInput,
    required this.detectedIntent,
    required this.extractedPayloadJson,
    required this.calculationResultJson,
    required this.suggestedActionJson,
    required this.actionStatus,
    required this.createdAt,
  });

  final String id;
  final String userInput;
  final SmartAssistantIntent detectedIntent;
  final String extractedPayloadJson;
  final String calculationResultJson;
  final String suggestedActionJson;
  final SmartAssistantActionStatus actionStatus;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userInput': userInput,
        'detectedIntent': detectedIntent.name,
        'extractedPayloadJson': extractedPayloadJson,
        'calculationResultJson': calculationResultJson,
        'suggestedActionJson': suggestedActionJson,
        'actionStatus': actionStatus.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SmartAssistantHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SmartAssistantHistoryEntry(
      id: map['id']?.toString() ?? '',
      userInput: map['userInput']?.toString() ?? '',
      detectedIntent: SmartAssistantIntent.values.firstWhere(
        (intent) => intent.name == map['detectedIntent']?.toString(),
        orElse: () => SmartAssistantIntent.unknown,
      ),
      extractedPayloadJson: map['extractedPayloadJson']?.toString() ?? '{}',
      calculationResultJson: map['calculationResultJson']?.toString() ?? '{}',
      suggestedActionJson: map['suggestedActionJson']?.toString() ?? '{}',
      actionStatus: SmartAssistantActionStatus.values.firstWhere(
        (status) => status.name == map['actionStatus']?.toString(),
        orElse: () => SmartAssistantActionStatus.preview,
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> get extractedPayload =>
      Map<String, dynamic>.from(jsonDecode(extractedPayloadJson) as Map);

  Map<String, dynamic> get calculationResult =>
      Map<String, dynamic>.from(jsonDecode(calculationResultJson) as Map);
}
