import '../../data/models/ai_proposal_model.dart';
import 'ai_business_memory.dart';
import 'ai_customer_credit_intelligence.dart';
import 'ai_data_collection_state.dart';
import 'ai_evidence_bundle.dart';
import 'ai_financial_decision_engine.dart';
import 'ai_financial_snapshot.dart';
import 'ai_insight_generator.dart';
import 'ai_risk_detector.dart';
import 'ai_tool_planner.dart';
import 'ai_workflow_session.dart';

class AiBusinessMemoryManager {
  AiBusinessMemoryManager({AiBusinessMemory? initialMemory})
      : _memory = initialMemory ?? AiBusinessMemory.empty();

  AiBusinessMemory _memory;

  AiBusinessMemory get memory => _memory;

  void clear() {
    _memory = AiBusinessMemory.empty();
  }

  bool rememberLongTerm(AiCfoMemoryItem item) {
    if (!_isSupportedMemory(item)) return false;
    final existing = _memory.longTermMemories;
    if (existing.any((memory) => _isDuplicate(memory, item))) return false;
    _memory = _memory.copyWith(
      longTermMemories: [item, ...existing].take(50).toList(),
      updatedAt: DateTime.now(),
    );
    return true;
  }

  void extractFromAnalysis({
    required AiToolPlan plan,
    required AiEvidenceBundle evidence,
    AiFinancialSnapshot? snapshot,
    List<AiFinancialRisk> risks = const [],
    List<AiFinancialRecommendation> recommendations = const [],
    DateTime? timestamp,
  }) {
    final at = timestamp ?? DateTime.now();
    if (plan.intent == AiAccountantIntent.customerBalanceAnalysis) {
      _extractCustomerCreditMemory(evidence, at);
    }
    _extractRiskMemories(plan: plan, evidence: evidence, risks: risks, at: at);
    _extractRecommendationMemories(
      plan: plan,
      evidence: evidence,
      recommendations: recommendations,
      at: at,
    );
    _extractSnapshotMemories(
      snapshot: snapshot,
      evidence: evidence,
      at: at,
    );
  }

  void extractFromDecision({
    required AiFinancialDecisionResult result,
    DateTime? timestamp,
  }) {
    final decision = result.shipmentDecision;
    if (decision == null) return;
    final at = timestamp ?? DateTime.now();
    rememberLongTerm(AiCfoMemoryItem(
      id: _stableId(
        category: AiCfoMemoryCategory.tradeImportExport,
        sourceType: 'import_export_decision',
        summary:
            'Shipment analysis was ${decision.riskLabel} with action ${decision.recommendedAction}.',
        relatedEntity: 'shipment',
      ),
      category: AiCfoMemoryCategory.tradeImportExport,
      summary:
          'This type of shipment was ${decision.riskLabel.toLowerCase()} in prior analysis; recommended action was ${decision.recommendedAction}.',
      source: 'Import / Export CFO Advisor',
      sourceType: 'import_export_decision',
      timestamp: at,
      confidence: decision.confidence,
      relatedEntity: 'shipment',
      evidenceReferences: [
        'expected revenue ${decision.expectedRevenue.toStringAsFixed(2)}',
        'total landed cost ${decision.totalLandedCost.toStringAsFixed(2)}',
        'margin ${decision.marginPercent.toStringAsFixed(2)}%',
        'break-even ${decision.breakEvenPointUnits} units',
      ],
    ));
  }

  List<AiCfoMemoryItem> retrieveRelevant({
    required AiAccountantIntent intent,
    String? userText,
    String? relatedEntity,
    int limit = 3,
  }) {
    final normalized = userText?.toLowerCase() ?? '';
    final categories = _categoriesForIntent(intent, normalized);
    final scored = _memory.longTermMemories
        .map((memory) => MapEntry(
            memory,
            _memoryScore(
              memory: memory,
              categories: categories,
              normalized: normalized,
              relatedEntity: relatedEntity,
            )))
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) {
        final score = b.value.compareTo(a.value);
        if (score != 0) return score;
        return b.key.timestamp.compareTo(a.key.timestamp);
      });
    return scored.map((entry) => entry.key).take(limit).toList();
  }

  String summarizeRelevant({
    required AiAccountantIntent intent,
    String? userText,
    String? relatedEntity,
    int limit = 3,
  }) {
    final memories = retrieveRelevant(
      intent: intent,
      userText: userText,
      relatedEntity: relatedEntity,
      limit: limit,
    );
    if (memories.isEmpty) return '';
    return memories.map((memory) {
      return '${memory.categoryLabel}: ${memory.summary} '
          '(source: ${memory.source}, confidence: ${memory.confidence.name.toUpperCase()})';
    }).join('\n');
  }

  void updateFromConversation({
    required String text,
    String? topic,
    String? product,
    String? customer,
  }) {
    final normalized = text.toLowerCase();
    var next = _memory;
    final detectedProduct = product ?? _detectProduct(normalized);
    final detectedCustomer = customer ?? _detectNamedValue(text, 'customer');
    final detectedSupplier = _detectNamedValue(text, 'supplier');
    final detectedTopic = topic ?? _detectTopic(normalized);

    if (detectedProduct != null) {
      next = next.copyWith(
        recentProducts: _remember(next.recentProducts, detectedProduct),
      );
    }
    if (detectedCustomer != null) {
      next = next.copyWith(
        recentCustomers: _remember(next.recentCustomers, detectedCustomer),
      );
    }
    if (detectedSupplier != null) {
      next = next.copyWith(
        recentSuppliers: _remember(next.recentSuppliers, detectedSupplier),
      );
    }
    if (detectedTopic != null) {
      next = next.copyWith(
        recentTopics: _remember(next.recentTopics, detectedTopic),
      );
    }
    if (normalized.contains('price') ||
        normalized.contains('pricing') ||
        normalized.contains('margin') ||
        normalized.contains('تسعير')) {
      next = next.copyWith(
          lastPricingContext: _safeContext(detectedProduct, detectedTopic));
    }
    if (normalized.contains('export') ||
        normalized.contains('shipping') ||
        normalized.contains('saudi') ||
        normalized.contains('تصدير')) {
      next = next.copyWith(
          lastExportContext: _safeContext(detectedProduct, detectedTopic));
    }
    _memory = next.copyWith(updatedAt: DateTime.now());
  }

  void updateFromWorkflow(AiWorkflowSession session) {
    var next = _memory.copyWith(
      recentWorkflowTypes: _remember(
        _memory.recentWorkflowTypes,
        session.workflowType.name,
      ),
    );
    final product = session.collectedData[AiWorkflowField.product]?.toString();
    final customer =
        session.collectedData[AiWorkflowField.customer]?.toString();
    final supplier =
        session.collectedData[AiWorkflowField.supplier]?.toString();
    if (product != null && product.trim().isNotEmpty) {
      next = next.copyWith(
          recentProducts: _remember(next.recentProducts, product));
    }
    if (customer != null && customer.trim().isNotEmpty) {
      next = next.copyWith(
          recentCustomers: _remember(next.recentCustomers, customer));
    }
    if (supplier != null && supplier.trim().isNotEmpty) {
      next = next.copyWith(
          recentSuppliers: _remember(next.recentSuppliers, supplier));
    }
    if (session.workflowType == AiWorkflowType.pricing && product != null) {
      next = next.copyWith(lastPricingContext: 'Pricing: $product');
    }
    _memory = next.copyWith(updatedAt: DateTime.now());
  }

  void updateFromProposal(AiProposalModel proposal) {
    var next = _memory.copyWith(
      lastProposalContext: proposal.actionType,
      recentTopics: _remember(_memory.recentTopics, proposal.actionType),
    );
    final product = proposal.inventoryPayload?['name']?.toString();
    final customer = proposal.customerPayload?['name']?.toString();
    final destination = proposal.pricingPayload?['destination']?.toString();
    if (product != null && product.trim().isNotEmpty) {
      next = next.copyWith(
          recentProducts: _remember(next.recentProducts, product));
    }
    if (customer != null && customer.trim().isNotEmpty) {
      next = next.copyWith(
          recentCustomers: _remember(next.recentCustomers, customer));
    }
    if (proposal.actionType == 'pricing_simulation') {
      next = next.copyWith(
        lastPricingContext: [
          if (product != null && product.trim().isNotEmpty) product.trim(),
          if (destination != null && destination.trim().isNotEmpty)
            destination.trim(),
        ].join(' | '),
      );
    }
    _memory = next.copyWith(updatedAt: DateTime.now());
  }

  String summarizeSafely() {
    final parts = <String>[
      if (_memory.recentProducts.isNotEmpty)
        'recent products: ${_memory.recentProducts.take(3).join(', ')}',
      if (_memory.recentCustomers.isNotEmpty)
        'recent customers: ${_memory.recentCustomers.take(3).join(', ')}',
      if (_memory.recentSuppliers.isNotEmpty)
        'recent suppliers: ${_memory.recentSuppliers.take(3).join(', ')}',
      if (_memory.recentTopics.isNotEmpty)
        'recent topics: ${_memory.recentTopics.take(3).join(', ')}',
      if (_memory.recentWorkflowTypes.isNotEmpty)
        'recent workflows: ${_memory.recentWorkflowTypes.take(3).join(', ')}',
      if (_memory.lastPricingContext != null)
        'last pricing context: ${_memory.lastPricingContext}',
      if (_memory.lastExportContext != null)
        'last export context: ${_memory.lastExportContext}',
      if (_memory.lastProposalContext != null)
        'last proposal context: ${_memory.lastProposalContext}',
      if (_memory.longTermMemories.isNotEmpty)
        'long-term memories: ${_memory.longTermMemories.take(3).map((item) => item.summary).join(' | ')}',
    ];
    return parts.join('; ');
  }

  void _extractCustomerCreditMemory(
    AiEvidenceBundle evidence,
    DateTime at,
  ) {
    final report = AiCustomerCreditIntelligence().analyze(evidence);
    final customer = report.riskiestCustomer;
    if (customer == null || customer.overdueCount <= 0) return;
    rememberLongTerm(AiCfoMemoryItem(
      id: _stableId(
        category: AiCfoMemoryCategory.customer,
        sourceType: 'customer_credit_analysis',
        summary:
            '${customer.customerName} has delayed payments before (${customer.overdueCount} overdue invoices).',
        relatedEntity: customer.customerName,
      ),
      category: AiCfoMemoryCategory.customer,
      summary:
          '${customer.customerName} has delayed payments before: ${customer.overdueCount} overdue invoices and ${customer.outstandingBalance.toStringAsFixed(2)} outstanding.',
      source: 'Customer Credit Intelligence',
      sourceType: 'customer_credit_analysis',
      timestamp: at,
      confidence: customer.confidence,
      relatedEntity: customer.customerName,
      evidenceReferences: customer.evidence,
    ));
  }

  void _extractRiskMemories({
    required AiToolPlan plan,
    required AiEvidenceBundle evidence,
    required List<AiFinancialRisk> risks,
    required DateTime at,
  }) {
    for (final risk in risks) {
      if (risk.title == 'No major risk detected' ||
          risk.title == 'Missing evidence') {
        continue;
      }
      final category = switch (risk.title) {
        'Overdue invoices' => AiCfoMemoryCategory.financial,
        'Low stock' => AiCfoMemoryCategory.inventory,
        'Customer balances' => AiCfoMemoryCategory.customer,
        _ => AiCfoMemoryCategory.operational,
      };
      rememberLongTerm(AiCfoMemoryItem(
        id: _stableId(
          category: category,
          sourceType: 'risk_detection',
          summary: '${risk.title}: ${risk.description}',
          relatedEntity: null,
        ),
        category: category,
        summary: '${risk.title}: ${risk.description}',
        source: 'AI Risk Detector',
        sourceType: 'risk_detection',
        timestamp: at,
        confidence: evidence.confidenceLevel,
        evidenceReferences: _evidenceReferences(evidence, plan),
      ));
    }
  }

  void _extractRecommendationMemories({
    required AiToolPlan plan,
    required AiEvidenceBundle evidence,
    required List<AiFinancialRecommendation> recommendations,
    required DateTime at,
  }) {
    for (final recommendation in recommendations) {
      if (recommendation.title == 'Keep monitoring') continue;
      rememberLongTerm(AiCfoMemoryItem(
        id: _stableId(
          category: AiCfoMemoryCategory.recommendation,
          sourceType: 'cfo_recommendation',
          summary: '${recommendation.title}: ${recommendation.description}',
          relatedEntity: null,
        ),
        category: AiCfoMemoryCategory.recommendation,
        summary:
            'This recommendation repeats a previous CFO warning: ${recommendation.title}. ${recommendation.description}',
        source: 'AI Insight Generator',
        sourceType: 'cfo_recommendation',
        timestamp: at,
        confidence: evidence.confidenceLevel,
        evidenceReferences: _evidenceReferences(evidence, plan),
      ));
    }
  }

  void _extractSnapshotMemories({
    required AiFinancialSnapshot? snapshot,
    required AiEvidenceBundle evidence,
    required DateTime at,
  }) {
    if (snapshot == null || snapshot.pendingInvoices == null) return;
    if (snapshot.pendingInvoices! <= 0) return;
    rememberLongTerm(AiCfoMemoryItem(
      id: _stableId(
        category: AiCfoMemoryCategory.financial,
        sourceType: 'financial_snapshot',
        summary:
            'Cash reserve risk previously included pending invoices ${snapshot.pendingInvoices!.toStringAsFixed(2)}.',
        relatedEntity: 'cashflow',
      ),
      category: AiCfoMemoryCategory.financial,
      summary:
          'You had a similar cash reserve risk previously: pending invoices were ${snapshot.pendingInvoices!.toStringAsFixed(2)}.',
      source: 'AI Financial Snapshot',
      sourceType: 'financial_snapshot',
      timestamp: at,
      confidence: snapshot.confidence,
      relatedEntity: 'cashflow',
      evidenceReferences: [
        'pending invoices ${snapshot.pendingInvoices!.toStringAsFixed(2)}',
        if (snapshot.overdueInvoices != null)
          'overdue invoices ${snapshot.overdueInvoices}',
      ],
    ));
  }

  bool _isSupportedMemory(AiCfoMemoryItem item) {
    return item.summary.trim().isNotEmpty &&
        item.source.trim().isNotEmpty &&
        item.sourceType.trim().isNotEmpty &&
        item.evidenceReferences.isNotEmpty &&
        item.confidence != AiEvidenceConfidence.low;
  }

  bool _isDuplicate(AiCfoMemoryItem a, AiCfoMemoryItem b) {
    return a.category == b.category &&
        a.sourceType == b.sourceType &&
        (a.relatedEntity ?? '').toLowerCase() ==
            (b.relatedEntity ?? '').toLowerCase() &&
        _fingerprint(a.summary) == _fingerprint(b.summary);
  }

  List<String> _evidenceReferences(AiEvidenceBundle evidence, AiToolPlan plan) {
    final refs = evidence.executedTools
        .where((tool) => tool.success)
        .map((tool) => '${tool.toolName}: ${tool.reason}')
        .toList();
    if (refs.isNotEmpty) return refs;
    return plan.steps
        .map((step) => '${step.toolName}: ${step.reason}')
        .toList();
  }

  Set<AiCfoMemoryCategory> _categoriesForIntent(
    AiAccountantIntent intent,
    String normalized,
  ) {
    final categories = <AiCfoMemoryCategory>{
      AiCfoMemoryCategory.recommendation,
    };
    switch (intent) {
      case AiAccountantIntent.customerBalanceAnalysis:
        categories.add(AiCfoMemoryCategory.customer);
      case AiAccountantIntent.cashFlowAnalysis:
      case AiAccountantIntent.financialOverview:
      case AiAccountantIntent.invoiceAnalysis:
        categories.add(AiCfoMemoryCategory.financial);
        categories.add(AiCfoMemoryCategory.customer);
      case AiAccountantIntent.inventoryAnalysis:
        categories.add(AiCfoMemoryCategory.inventory);
      case AiAccountantIntent.exportDecision:
      case AiAccountantIntent.pricingDecision:
        categories.add(AiCfoMemoryCategory.tradeImportExport);
      case AiAccountantIntent.profitabilityAnalysis:
        categories.add(AiCfoMemoryCategory.financial);
      case AiAccountantIntent.generalAdvice:
      case AiAccountantIntent.unknown:
      case AiAccountantIntent.purchasePreparation:
      case AiAccountantIntent.salePreparation:
      case AiAccountantIntent.executionIntent:
        categories.add(AiCfoMemoryCategory.operational);
    }
    if (normalized.contains('cash')) {
      categories.add(AiCfoMemoryCategory.financial);
    }
    if (normalized.contains('customer') || normalized.contains('credit')) {
      categories.add(AiCfoMemoryCategory.customer);
    }
    if (normalized.contains('shipment') ||
        normalized.contains('import') ||
        normalized.contains('export')) {
      categories.add(AiCfoMemoryCategory.tradeImportExport);
    }
    if (normalized.contains('inventory') || normalized.contains('stock')) {
      categories.add(AiCfoMemoryCategory.inventory);
    }
    return categories;
  }

  int _memoryScore({
    required AiCfoMemoryItem memory,
    required Set<AiCfoMemoryCategory> categories,
    required String normalized,
    required String? relatedEntity,
  }) {
    var score = 0;
    if (categories.contains(memory.category)) score += 4;
    final entity = relatedEntity?.toLowerCase().trim();
    if (entity != null &&
        entity.isNotEmpty &&
        (memory.relatedEntity ?? '').toLowerCase().contains(entity)) {
      score += 3;
    }
    final summary = memory.summary.toLowerCase();
    for (final token in normalized.split(RegExp(r'\s+'))) {
      if (token.length >= 4 && summary.contains(token)) score += 1;
    }
    return score;
  }

  String _stableId({
    required AiCfoMemoryCategory category,
    required String sourceType,
    required String summary,
    required String? relatedEntity,
  }) {
    return 'cfo_${category.name}_${sourceType}_${_fingerprint('${relatedEntity ?? ''}|$summary')}';
  }

  String _fingerprint(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  List<String> _remember(List<String> current, String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return current;
    final withoutDuplicate = current
        .where((item) => item.toLowerCase() != cleaned.toLowerCase())
        .toList();
    return [cleaned, ...withoutDuplicate].take(5).toList();
  }

  String? _detectProduct(String normalized) {
    const known = {
      'chocolate': 'chocolate',
      'شوكولاتة': 'chocolate',
      'hobby': 'Ülker Hobby',
      'ulker': 'Ülker Hobby',
      'ülker': 'Ülker Hobby',
    };
    for (final entry in known.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return _detectNamedValue(normalized, 'product');
  }

  String? _detectTopic(String normalized) {
    if (normalized.contains('invoice') ||
        normalized.contains('collection') ||
        normalized.contains('تحصيل')) {
      return 'collections';
    }
    if (normalized.contains('cash')) return 'cashflow';
    if (normalized.contains('inventory') || normalized.contains('stock')) {
      return 'inventory';
    }
    if (normalized.contains('pricing') ||
        normalized.contains('price') ||
        normalized.contains('margin')) {
      return 'pricing';
    }
    if (normalized.contains('export') || normalized.contains('shipping')) {
      return 'export';
    }
    return null;
  }

  String? _detectNamedValue(String text, String label) {
    final expression =
        RegExp('$label\\s*[:=]\\s*([^,.;\\n]+)', caseSensitive: false);
    final match = expression.firstMatch(text);
    return match?.group(1)?.trim();
  }

  String _safeContext(String? primary, String? topic) {
    return [
      if (topic != null) topic,
      if (primary != null) primary,
    ].join(': ');
  }
}
