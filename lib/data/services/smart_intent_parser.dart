import '../models/smart_assistant_models.dart';

class SmartIntentParser {
  SmartAssistantParseResult parse(String input) {
    final normalized = _normalize(input);
    final extracted = <String, dynamic>{};
    final warnings = <String>[];

    final numbers = _extractNumbers(normalized);
    extracted['numbers'] = numbers;
    extracted.addAll(_extractMoneyAndBusinessFields(normalized, numbers));

    final productName = _extractProductName(normalized);
    if (productName != null) extracted['productName'] = productName;

    final customerName = _extractCustomerName(normalized);
    if (customerName != null) extracted['customerName'] = customerName;

    final intent = _detectIntent(normalized);
    final missing = _missingFields(intent, extracted);
    final confidence = _confidence(intent, extracted, missing);

    if (normalized.contains('expiry') ||
        normalized.contains('انتهاء') ||
        normalized.contains('صلاحية')) {
      warnings.add(
          'Expiry mentioned. Add an expiry date manually before confirming.');
    }

    return SmartAssistantParseResult(
      userInput: input,
      intent: intent,
      extracted: extracted,
      missingFields: missing,
      warnings: warnings,
      confidence: confidence,
      suggestedAction: _suggestedAction(intent, extracted),
    );
  }

  SmartAssistantParseResult complete(
    SmartAssistantParseResult result,
    Map<String, dynamic> updates,
  ) {
    final extracted = {...result.extracted, ...updates};
    return result.copyWith(
      extracted: extracted,
      missingFields: _missingFields(result.intent, extracted),
      confidence: _confidence(
          result.intent, extracted, _missingFields(result.intent, extracted)),
      suggestedAction: _suggestedAction(result.intent, extracted),
    );
  }

  SmartAssistantIntent _detectIntent(String input) {
    final hasAdd = _has(input, ['add', 'create', 'ضيف', 'اضف', 'أضف', 'زود']);
    final hasSale =
        _has(input, ['sold', 'sale', 'sell', 'بعت', 'بيع', 'مبيعات']);
    final hasPurchase =
        _has(input, ['bought', 'purchase', 'stock', 'اشتريت', 'شراء', 'مخزون']);
    final hasProfit = _has(input, ['profit', 'margin', 'ربح', 'هامش']);
    final hasTax = _has(input, ['tax', 'vat', 'ضريبة', 'قيمة مضافة']);
    final hasDiscount = _has(input, ['discount', 'خصم']);
    final hasRemaining =
        _has(input, ['remaining', 'balance', 'paid', 'باقي', 'دفع', 'رصيد']);
    final hasExpense = _has(input, ['expense', 'cost', 'مصروف', 'شحن']);
    final hasReminder =
        _has(input, ['remind', 'alert', 'notify', 'نبه', 'ذكرني', 'تنبيه']);
    final hasQuery =
        _has(input, ['show', 'what', 'list', 'query', 'اعرض', 'كم', 'تقرير']);

    if (_has(input, ['low stock', 'اقل من', 'أقل من', 'منخفض'])) {
      return SmartAssistantIntent.lowStockQuery;
    }
    if (_has(input, ['inventory value', 'قيمة المخزون'])) {
      return SmartAssistantIntent.inventoryValueQuery;
    }
    if (_has(input, ['customer balances', 'ارصدة العملاء', 'أرصدة العملاء'])) {
      return SmartAssistantIntent.customerBalancesQuery;
    }
    if (_has(input, ['monthly sales', 'مبيعات الشهر'])) {
      return SmartAssistantIntent.monthlySalesQuery;
    }
    if (_has(input, ['monthly expense', 'مصروفات الشهر'])) {
      return SmartAssistantIntent.monthlyExpensesQuery;
    }
    if (_has(input, ['best selling', 'الاكثر مبيعا', 'الأكثر مبيعا'])) {
      return SmartAssistantIntent.bestSellingProductsQuery;
    }
    if (_has(input, ['most profitable', 'الاكثر ربحا', 'الأكثر ربحا'])) {
      return SmartAssistantIntent.mostProfitableProductsQuery;
    }

    if (hasReminder) return SmartAssistantIntent.createReminderDraft;
    if (hasExpense && hasAdd) return SmartAssistantIntent.createExpenseDraft;
    if (hasSale && hasAdd && !hasPurchase) {
      return SmartAssistantIntent.createSaleDraft;
    }
    if (hasSale && !hasProfit && !hasPurchase) {
      return SmartAssistantIntent.createSaleDraft;
    }
    if (hasPurchase && (hasAdd || hasProfit || _has(input, ['sell', 'بيع']))) {
      return SmartAssistantIntent.addProductDraft;
    }
    if (hasPurchase && _has(input, ['update', 'adjust', 'تعديل', 'سوي'])) {
      return SmartAssistantIntent.updateStockDraft;
    }
    if (hasTax) return SmartAssistantIntent.calculateTax;
    if (hasDiscount) return SmartAssistantIntent.calculateDiscount;
    if (hasRemaining) return SmartAssistantIntent.calculateRemainingBalance;
    if (hasProfit && _has(input, ['margin', 'هامش'])) {
      return SmartAssistantIntent.calculateMargin;
    }
    if (hasProfit) return SmartAssistantIntent.calculateProfit;
    if (_has(input, ['unit price', 'سعر الوحدة'])) {
      return SmartAssistantIntent.calculateUnitPrice;
    }
    if (_has(input, ['total cost', 'تكلفة'])) {
      return SmartAssistantIntent.calculateTotalCost;
    }
    if (_has(input, ['total sale', 'اجمالي البيع', 'إجمالي البيع'])) {
      return SmartAssistantIntent.calculateSaleTotal;
    }
    if (hasQuery) return SmartAssistantIntent.unknown;
    return SmartAssistantIntent.unknown;
  }

  Map<String, dynamic> _extractMoneyAndBusinessFields(
      String input, List<double> numbers) {
    final data = <String, dynamic>{};

    final quantity = _firstAfter(input, [
      RegExp(r'(?:qty|quantity|عدد|كمية|اشتريت|بعت)\s+([0-9]+(?:\.[0-9]+)?)'),
      RegExp(
          r'([0-9]+(?:\.[0-9]+)?)\s+(?:pcs|pieces|units|cartons|قطعة|قطع|كرتونة|كرتون|منتج|منتجات)'),
    ]);
    if (quantity != null) data['quantity'] = quantity;

    final purchase = _firstAfter(input, [
      RegExp(
          r'(?:cost|purchase price|bought for|تكلفة|بسعر|شراء)\s+([0-9]+(?:\.[0-9]+)?)'),
      RegExp(r'(?:السعر|سعر)\s+([0-9]+(?:\.[0-9]+)?)'),
    ]);
    if (purchase != null) data['purchasePrice'] = purchase;

    final sale = _firstAfter(input, [
      RegExp(
          r'(?:sell for|sale price|selling price|ابيعها|أبيعها|بيعها|بسعر بيع|selling)\s+([0-9]+(?:\.[0-9]+)?)'),
      RegExp(
          r'(?:بدي بيعها|بدي ابيعها|وبدي بيعها|وبدي ابيعها)\s+([0-9]+(?:\.[0-9]+)?)'),
    ]);
    if (sale != null) data['salePrice'] = sale;

    final paid =
        _firstAfter(input, [RegExp(r'(?:paid|دفع)\s+([0-9]+(?:\.[0-9]+)?)')]);
    if (paid != null) data['paidAmount'] = paid;

    final remaining = _firstAfter(
        input, [RegExp(r'(?:remaining|باقي|متبقي).*?([0-9]+(?:\.[0-9]+)?)')]);
    if (remaining != null) data['remainingAmount'] = remaining;

    final percent = _firstAfter(input, [
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*%'),
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(?:percent|بالمية|بالمئة)')
    ]);
    if (percent != null) {
      if (_has(input, ['tax', 'vat', 'ضريبة'])) {
        data['taxPercent'] = percent;
      } else {
        data['discountPercent'] = percent;
      }
    }

    if (numbers.length >= 2) {
      data.putIfAbsent('quantity', () => numbers[0]);
      data.putIfAbsent('purchasePrice', () => numbers[1]);
    }
    if (numbers.length >= 3) data.putIfAbsent('salePrice', () => numbers[2]);
    if (numbers.length == 1) data.putIfAbsent('amount', () => numbers.first);

    final currency = RegExp(r'(usd|dollar|try|tl|ليرة|دولار|ريال|درهم)',
            caseSensitive: false)
        .firstMatch(input);
    if (currency != null) data['currency'] = currency.group(1);

    return data;
  }

  List<String> _missingFields(
      SmartAssistantIntent intent, Map<String, dynamic> data) {
    final required = switch (intent) {
      SmartAssistantIntent.calculateProfit ||
      SmartAssistantIntent.calculateMargin ||
      SmartAssistantIntent.addProductDraft =>
        ['quantity', 'purchasePrice', 'salePrice'],
      SmartAssistantIntent.calculateTax => ['taxPercent'],
      SmartAssistantIntent.calculateDiscount => ['discountPercent'],
      SmartAssistantIntent.calculateRemainingBalance ||
      SmartAssistantIntent.createCustomerPaymentDraft =>
        ['paidAmount'],
      SmartAssistantIntent.createSaleDraft => ['quantity', 'salePrice'],
      SmartAssistantIntent.createExpenseDraft => ['amount'],
      SmartAssistantIntent.updateStockDraft => ['productName', 'quantity'],
      SmartAssistantIntent.createReminderDraft => ['productName', 'quantity'],
      _ => <String>[],
    };
    return required
        .where((field) =>
            data[field] == null || data[field].toString().trim().isEmpty)
        .toList();
  }

  Map<String, dynamic>? _suggestedAction(
      SmartAssistantIntent intent, Map<String, dynamic> data) {
    if (!{
      SmartAssistantIntent.addProductDraft,
      SmartAssistantIntent.updateStockDraft,
      SmartAssistantIntent.createSaleDraft,
      SmartAssistantIntent.createCustomerPaymentDraft,
      SmartAssistantIntent.createExpenseDraft,
      SmartAssistantIntent.createReminderDraft,
    }.contains(intent)) {
      return null;
    }
    return {'type': intent.name, 'payload': data};
  }

  String _normalize(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
    const englishDigits = '01234567890123456789';
    var out = input.toLowerCase();
    for (var i = 0; i < arabicDigits.length; i++) {
      out = out.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return out.replaceAll(',', '.');
  }

  List<double> _extractNumbers(String input) {
    return RegExp(r'[0-9]+(?:\.[0-9]+)?')
        .allMatches(input)
        .map((m) => double.parse(m.group(0)!))
        .toList();
  }

  double? _firstAfter(String input, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) return double.tryParse(match.group(1)!);
    }
    return null;
  }

  String? _extractProductName(String input) {
    final patterns = [
      RegExp(
          r'(?:product|item|منتج|المنتج|صنف|مخزون)\s+([a-z0-9_\u0600-\u06FF -]+?)(?:\s+(?:بسعر|price|for|ب|qty|quantity|عدد|كمية)|$)',
          unicode: true),
      RegExp(
          r'(?:كرتونة|قطعة|قطع|منتجات?)\s+([a-z_\u0600-\u06FF -]+?)(?:\s+(?:بسعر|price|وبدي|بدي)|$)',
          unicode: true),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _extractCustomerName(String input) {
    final match = RegExp(
            r'(?:customer|client|زبون|عميل)\s+([a-z_\u0600-\u06FF -]+?)(?:\s+(?:paid|دفع|باقي)|$)',
            unicode: true)
        .firstMatch(input);
    return match?.group(1)?.trim();
  }

  bool _has(String input, List<String> words) => words.any(input.contains);

  double _confidence(
    SmartAssistantIntent intent,
    Map<String, dynamic> data,
    List<String> missing,
  ) {
    if (intent == SmartAssistantIntent.unknown) return 0.18;
    final base = 0.56 + (data.length.clamp(0, 6) * 0.06);
    return (base - missing.length * 0.12).clamp(0.2, 0.98);
  }
}
