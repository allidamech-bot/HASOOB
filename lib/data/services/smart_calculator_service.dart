import '../models/product_model.dart';
import '../models/smart_assistant_models.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/smart_assistant_history_repository.dart';
import 'smart_calculation_engine.dart';
import 'smart_intent_parser.dart';

class SmartCalculatorService {
  SmartCalculatorService({
    SmartIntentParser? parser,
    SmartCalculationEngine? engine,
    SmartAssistantHistoryRepository? historyRepository,
    ProductRepository? productRepository,
    CustomerRepository? customerRepository,
  })  : _parser = parser ?? SmartIntentParser(),
        _engine = engine ?? SmartCalculationEngine(),
        _historyRepository =
            historyRepository ?? SmartAssistantHistoryRepository(),
        _productRepository = productRepository ?? ProductRepository(),
        _customerRepository = customerRepository ?? CustomerRepository();

  final SmartIntentParser _parser;
  final SmartCalculationEngine _engine;
  final SmartAssistantHistoryRepository _historyRepository;
  final ProductRepository _productRepository;
  final CustomerRepository _customerRepository;

  Future<SmartAssistantPreview> preview(String input) async {
    final parse = _parser.parse(input);
    final calculation = _engine.calculate(parse);
    final preview = SmartAssistantPreview(
      parse: parse,
      calculation: calculation,
      fields: _fields(parse, calculation),
    );
    await _historyRepository.savePreview(preview);
    return preview;
  }

  SmartAssistantPreview previewWithFields(
    SmartAssistantPreview current,
    Map<String, dynamic> updates,
  ) {
    final parse = _parser.complete(current.parse, updates);
    final calculation = _engine.calculate(parse);
    return SmartAssistantPreview(
      parse: parse,
      calculation: calculation,
      fields: _fields(parse, calculation),
    );
  }

  Future<void> saveDraft(SmartAssistantPreview preview) {
    return _historyRepository.saveDraft(preview);
  }

  Future<String> confirm({
    required String businessId,
    required SmartAssistantPreview preview,
  }) async {
    if (!preview.parse.isReady) {
      throw StateError(
          'Missing required fields: ${preview.parse.missingFields.join(', ')}');
    }

    final data = preview.parse.extracted;
    final result = switch (preview.parse.intent) {
      SmartAssistantIntent.addProductDraft =>
        await _createProduct(businessId, data),
      SmartAssistantIntent.updateStockDraft =>
        await _updateStock(businessId, data),
      SmartAssistantIntent.createSaleDraft =>
        await _createSale(businessId, data),
      SmartAssistantIntent.createCustomerPaymentDraft =>
        await _saveCustomerPaymentDraft(businessId, data),
      SmartAssistantIntent.createExpenseDraft ||
      SmartAssistantIntent.createReminderDraft =>
        'Draft saved locally in assistant history.',
      _ => 'Calculation saved locally in assistant history.',
    };

    await _historyRepository.markSaved(preview);
    return result;
  }

  Future<List<SmartAssistantHistoryEntry>> recentHistory() =>
      _historyRepository.recent();

  Future<List<SmartAssistantHistoryEntry>> searchHistory(String query) {
    if (query.trim().isEmpty) return recentHistory();
    return _historyRepository.search(query);
  }

  Future<Map<String, dynamic>> queryBusiness({
    required String businessId,
    required SmartAssistantIntent intent,
  }) async {
    switch (intent) {
      case SmartAssistantIntent.inventoryValueQuery:
        return {
          'inventoryValue':
              await _productRepository.getTotalInventoryValue(businessId)
        };
      case SmartAssistantIntent.lowStockQuery:
        return {
          'products': await _productRepository.getLowStockProducts(businessId)
        };
      case SmartAssistantIntent.customerBalancesQuery:
        return {
          'customers': await _customerRepository.getCustomers(businessId)
        };
      case SmartAssistantIntent.bestSellingProductsQuery:
      case SmartAssistantIntent.mostProfitableProductsQuery:
        return {
          'products': await _productRepository.getTopSellingProducts(businessId)
        };
      case SmartAssistantIntent.monthlySalesQuery:
        return {'sales': await _productRepository.getSalesRecords(businessId)};
      default:
        return const {};
    }
  }

  Future<String> _createProduct(
      String businessId, Map<String, dynamic> data) async {
    final now = DateTime.now();
    final productName = data['productName']?.toString().trim();
    final product = ProductModel(
      id: 'PRD_${now.microsecondsSinceEpoch}',
      businessId: businessId,
      name: productName == null || productName.isEmpty
          ? 'Smart draft product'
          : productName,
      unit: data['unit']?.toString() ?? 'unit',
      purchasePrice: _double(data['purchasePrice']),
      sellingPrice: _double(data['salePrice']),
      stockQty: _double(data['quantity']).round(),
      lowStockThreshold:
          _double(data['lowStockThreshold']).round().clamp(0, 999999),
      createdAt: now,
      updatedAt: now,
    );
    await _productRepository.addProduct(businessId, product);
    return 'Product added to inventory.';
  }

  Future<String> _updateStock(
      String businessId, Map<String, dynamic> data) async {
    final products = await _productRepository.getAllProducts(businessId);
    final name = data['productName']?.toString().trim().toLowerCase() ?? '';
    final match =
        products.where((p) => p.name.toLowerCase().contains(name)).firstOrNull;
    if (match == null) throw StateError('Product not found for stock update.');
    await _productRepository.applyInventoryAdjustment(
      businessId: businessId,
      productId: match.id,
      newStockQty: _double(data['quantity']).round(),
      reason: 'Smart calculator confirmed stock update',
    );
    return 'Stock updated for ${match.name}.';
  }

  Future<String> _createSale(
      String businessId, Map<String, dynamic> data) async {
    final products = await _productRepository.getAllProducts(businessId);
    final name = data['productName']?.toString().trim().toLowerCase() ?? '';
    final match = name.isEmpty
        ? null
        : products
            .where((p) => p.name.toLowerCase().contains(name))
            .firstOrNull;
    if (match == null) {
      await _historyRepository.saveDraft(SmartAssistantPreview(
        parse: SmartAssistantParseResult(
          userInput: 'sale draft',
          intent: SmartAssistantIntent.createSaleDraft,
          extracted: data,
          missingFields: const [],
          warnings: const [
            'Sale saved as draft because no matching product was found.'
          ],
          confidence: 0.6,
          suggestedAction: {'type': 'createSaleDraft', 'payload': data},
        ),
        calculation: _engine.calculate(SmartAssistantParseResult(
          userInput: 'sale draft',
          intent: SmartAssistantIntent.createSaleDraft,
          extracted: data,
          missingFields: const [],
          warnings: const [],
          confidence: 0.6,
        )),
        fields: const [],
      ));
      return 'Sale draft saved. Match a product before posting stock movement.';
    }
    await _productRepository.sellProduct(
      businessId: businessId,
      productId: match.id,
      qty: _double(data['quantity']).round(),
      sellingPrice: _double(data['salePrice']),
      customerName: data['customerName']?.toString(),
      saleNote: 'Created from offline smart calculator',
      currencyCode: data['currency']?.toString(),
    );
    return 'Sale recorded for ${match.name}.';
  }

  Future<String> _saveCustomerPaymentDraft(
      String businessId, Map<String, dynamic> data) async {
    if ((data['customerName']?.toString().trim().isNotEmpty ?? false)) {
      await _customerRepository.saveCustomer(businessId, {
        'name': data['customerName'].toString().trim(),
        'notes':
            'Payment draft from smart calculator. Paid: ${data['paidAmount'] ?? 0}, remaining: ${data['remainingAmount'] ?? 0}',
      });
    }
    return 'Customer payment draft saved.';
  }

  List<SmartAssistantField> _fields(
    SmartAssistantParseResult parse,
    SmartCalculationResult calculation,
  ) {
    final fields = <SmartAssistantField>[];
    void add(String key, String label, Object? value) {
      if (value != null && value.toString().isNotEmpty) {
        fields.add(SmartAssistantField(key: key, label: label, value: value));
      }
    }

    add('intent', 'Intent', parse.intent.name);
    parse.extracted.forEach((key, value) {
      if (key != 'numbers') add(key, _label(key), value);
    });
    calculation.values.forEach((key, value) => add(key, _label(key), value));
    return fields;
  }

  String _label(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .replaceAll('_', ' ')
        .trim();
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
