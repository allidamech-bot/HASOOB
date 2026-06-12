import '../../data/models/ai_proposal_model.dart';
import 'ai_business_memory.dart';
import 'ai_data_collection_state.dart';
import 'ai_workflow_session.dart';

class AiBusinessMemoryManager {
  AiBusinessMemoryManager({AiBusinessMemory? initialMemory})
      : _memory = initialMemory ?? AiBusinessMemory.empty();

  AiBusinessMemory _memory;

  AiBusinessMemory get memory => _memory;

  void clear() {
    _memory = AiBusinessMemory.empty();
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
    ];
    return parts.join('; ');
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
