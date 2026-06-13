import 'ai_evidence_bundle.dart';

enum AiCfoMemoryCategory {
  operational,
  financial,
  customer,
  inventory,
  recommendation,
  tradeImportExport,
}

class AiCfoMemoryItem {
  final String id;
  final AiCfoMemoryCategory category;
  final String summary;
  final String source;
  final String sourceType;
  final DateTime timestamp;
  final AiEvidenceConfidence confidence;
  final String? relatedEntity;
  final List<String> evidenceReferences;

  const AiCfoMemoryItem({
    required this.id,
    required this.category,
    required this.summary,
    required this.source,
    required this.sourceType,
    required this.timestamp,
    required this.confidence,
    this.relatedEntity,
    required this.evidenceReferences,
  });

  String get categoryLabel {
    switch (category) {
      case AiCfoMemoryCategory.operational:
        return 'operational memory';
      case AiCfoMemoryCategory.financial:
        return 'financial memory';
      case AiCfoMemoryCategory.customer:
        return 'customer memory';
      case AiCfoMemoryCategory.inventory:
        return 'inventory memory';
      case AiCfoMemoryCategory.recommendation:
        return 'recommendation memory';
      case AiCfoMemoryCategory.tradeImportExport:
        return 'trade/import-export memory';
    }
  }

  Map<String, dynamic> toSafeJson() => {
        'id': id,
        'category': category.name,
        'summary': summary,
        'source': source,
        'sourceType': sourceType,
        'timestamp': timestamp.toIso8601String(),
        'confidence': confidence.name,
        'relatedEntity': relatedEntity,
        'evidenceReferences': evidenceReferences,
      };
}

class AiBusinessMemory {
  final List<String> recentProducts;
  final List<String> recentCustomers;
  final List<String> recentSuppliers;
  final List<String> recentTopics;
  final List<String> recentWorkflowTypes;
  final String? lastPricingContext;
  final String? lastExportContext;
  final String? lastProposalContext;
  final List<AiCfoMemoryItem> longTermMemories;
  final DateTime updatedAt;

  const AiBusinessMemory({
    this.recentProducts = const [],
    this.recentCustomers = const [],
    this.recentSuppliers = const [],
    this.recentTopics = const [],
    this.recentWorkflowTypes = const [],
    this.lastPricingContext,
    this.lastExportContext,
    this.lastProposalContext,
    this.longTermMemories = const [],
    required this.updatedAt,
  });

  factory AiBusinessMemory.empty() {
    return AiBusinessMemory(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));
  }

  AiBusinessMemory copyWith({
    List<String>? recentProducts,
    List<String>? recentCustomers,
    List<String>? recentSuppliers,
    List<String>? recentTopics,
    List<String>? recentWorkflowTypes,
    String? lastPricingContext,
    String? lastExportContext,
    String? lastProposalContext,
    List<AiCfoMemoryItem>? longTermMemories,
    DateTime? updatedAt,
  }) {
    return AiBusinessMemory(
      recentProducts: recentProducts ?? this.recentProducts,
      recentCustomers: recentCustomers ?? this.recentCustomers,
      recentSuppliers: recentSuppliers ?? this.recentSuppliers,
      recentTopics: recentTopics ?? this.recentTopics,
      recentWorkflowTypes: recentWorkflowTypes ?? this.recentWorkflowTypes,
      lastPricingContext: lastPricingContext ?? this.lastPricingContext,
      lastExportContext: lastExportContext ?? this.lastExportContext,
      lastProposalContext: lastProposalContext ?? this.lastProposalContext,
      longTermMemories: longTermMemories ?? this.longTermMemories,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasVisibleMemory {
    return recentProducts.isNotEmpty ||
        recentCustomers.isNotEmpty ||
        recentSuppliers.isNotEmpty ||
        recentTopics.isNotEmpty ||
        recentWorkflowTypes.isNotEmpty ||
        lastPricingContext != null ||
        lastExportContext != null ||
        lastProposalContext != null ||
        longTermMemories.isNotEmpty;
  }

  Map<String, dynamic> toSafeJson() => {
        'recentProducts': recentProducts,
        'recentCustomers': recentCustomers,
        'recentSuppliers': recentSuppliers,
        'recentTopics': recentTopics,
        'recentWorkflowTypes': recentWorkflowTypes,
        'lastPricingContext': lastPricingContext,
        'lastExportContext': lastExportContext,
        'lastProposalContext': lastProposalContext,
        'longTermMemories':
            longTermMemories.map((item) => item.toSafeJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
