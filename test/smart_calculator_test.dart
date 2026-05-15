import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/models/product_model.dart';
import 'package:hasoob_app/data/models/smart_assistant_models.dart';
import 'package:hasoob_app/data/repositories/customer_repository.dart';
import 'package:hasoob_app/data/repositories/product_repository.dart';
import 'package:hasoob_app/data/repositories/smart_assistant_history_repository.dart';
import 'package:hasoob_app/data/services/smart_calculation_engine.dart';
import 'package:hasoob_app/data/services/smart_calculator_service.dart';
import 'package:hasoob_app/data/services/smart_intent_parser.dart';

void main() {
  group('SmartIntentParser', () {
    final parser = SmartIntentParser();

    test('parses Arabic purchase and profit draft', () {
      final result =
          parser.parse('اشتريت 20 كرتونة منظف بسعر 50 وبدي بيعها 75');

      expect(result.intent, SmartAssistantIntent.addProductDraft);
      expect(result.extracted['quantity'], 20);
      expect(result.extracted['purchasePrice'], 50);
      expect(result.extracted['salePrice'], 75);
      expect(result.missingFields, isEmpty);
    });

    test('parses English profit calculation', () {
      final result =
          parser.parse('Calculate profit for 10 units cost 12 sell for 20');

      expect(result.intent, SmartAssistantIntent.calculateProfit);
      expect(result.extracted['quantity'], 10);
      expect(result.extracted['purchasePrice'], 12);
      expect(result.extracted['salePrice'], 20);
    });

    test('parses mixed-language customer payment', () {
      final result = parser.parse('زبون Ahmad paid 500 وباقي عليه 200');

      expect(result.intent, SmartAssistantIntent.calculateRemainingBalance);
      expect(result.extracted['paidAmount'], 500);
      expect(result.extracted['remainingAmount'], 200);
    });

    test('reports missing fields instead of failing silently', () {
      final result = parser.parse('Calculate VAT on invoice');

      expect(result.intent, SmartAssistantIntent.calculateTax);
      expect(result.missingFields, contains('taxPercent'));
    });
  });

  group('SmartCalculationEngine', () {
    final engine = SmartCalculationEngine();

    test('calculates profit and margin', () {
      final result = engine.calculate(const SmartAssistantParseResult(
        userInput: 'profit',
        intent: SmartAssistantIntent.calculateProfit,
        extracted: {'quantity': 20, 'purchasePrice': 50, 'salePrice': 75},
        missingFields: [],
        warnings: [],
        confidence: .9,
      ));

      expect(result.values['totalCost'], 1000);
      expect(result.values['expectedRevenue'], 1500);
      expect(result.values['expectedProfit'], 500);
      expect(result.values['profitMargin'], 50);
    });

    test('calculates tax', () {
      final result = engine.calculate(const SmartAssistantParseResult(
        userInput: 'tax',
        intent: SmartAssistantIntent.calculateTax,
        extracted: {'totalAmount': 1200, 'taxPercent': 15},
        missingFields: [],
        warnings: [],
        confidence: .9,
      ));

      expect(result.values['tax'], 180);
      expect(result.values['totalWithTax'], 1380);
    });
  });

  group('SmartCalculatorService safety flow', () {
    test('creates preview and history without repository write', () async {
      final products = _FakeProductRepository();
      final history = _FakeHistoryRepository();
      final service = SmartCalculatorService(
        historyRepository: history,
        productRepository: products,
        customerRepository: _FakeCustomerRepository(),
      );

      final preview =
          await service.preview('Bought 3 units cost 10 sell for 15');

      expect(preview.parse.intent, SmartAssistantIntent.addProductDraft);
      expect(products.addProductCalls, 0);
      expect(history.previewCount, 1);
    });

    test('saves only after explicit confirmation', () async {
      final products = _FakeProductRepository();
      final history = _FakeHistoryRepository();
      final service = SmartCalculatorService(
        historyRepository: history,
        productRepository: products,
        customerRepository: _FakeCustomerRepository(),
      );

      final preview =
          await service.preview('Bought 3 units cost 10 sell for 15');
      await service.confirm(businessId: 'biz_1', preview: preview);

      expect(products.addProductCalls, 1);
      expect(history.savedCount, 1);
    });

    test('save draft creates history without product write', () async {
      final products = _FakeProductRepository();
      final history = _FakeHistoryRepository();
      final service = SmartCalculatorService(
        historyRepository: history,
        productRepository: products,
        customerRepository: _FakeCustomerRepository(),
      );

      final preview =
          await service.preview('Bought 3 units cost 10 sell for 15');
      await service.saveDraft(preview);

      expect(products.addProductCalls, 0);
      expect(history.draftCount, 1);
    });
  });
}

class _FakeHistoryRepository extends SmartAssistantHistoryRepository {
  int previewCount = 0;
  int draftCount = 0;
  int savedCount = 0;
  final entries = <SmartAssistantHistoryEntry>[];

  @override
  Future<void> savePreview(SmartAssistantPreview preview) async {
    previewCount++;
  }

  @override
  Future<void> saveDraft(SmartAssistantPreview preview) async {
    draftCount++;
  }

  @override
  Future<void> markSaved(SmartAssistantPreview preview) async {
    savedCount++;
  }

  @override
  Future<List<SmartAssistantHistoryEntry>> recent({int limit = 25}) async =>
      entries;

  @override
  Future<List<SmartAssistantHistoryEntry>> search(String query) async =>
      entries;
}

class _FakeProductRepository extends ProductRepository {
  int addProductCalls = 0;

  @override
  Future<void> addProduct(String businessId, ProductModel product) async {
    addProductCalls++;
  }
}

class _FakeCustomerRepository extends CustomerRepository {}
