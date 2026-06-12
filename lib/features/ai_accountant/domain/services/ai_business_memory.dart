class AiBusinessMemory {
  final List<String> recentProducts;
  final List<String> recentCustomers;
  final List<String> recentSuppliers;
  final List<String> recentTopics;
  final List<String> recentWorkflowTypes;
  final String? lastPricingContext;
  final String? lastExportContext;
  final String? lastProposalContext;
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
        lastProposalContext != null;
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
        'updatedAt': updatedAt.toIso8601String(),
      };
}
