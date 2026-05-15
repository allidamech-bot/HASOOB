import '../models/smart_assistant_models.dart';

class SmartCalculationEngine {
  SmartCalculationResult calculate(SmartAssistantParseResult parse) {
    final data = parse.extracted;
    final quantity = _num(data['quantity']);
    final purchasePrice = _num(data['purchasePrice'] ?? data['cost']);
    final salePrice = _num(data['salePrice'] ?? data['sellingPrice']);
    final totalCost = _num(data['totalCost']) > 0
        ? _num(data['totalCost'])
        : quantity * purchasePrice;
    final saleTotal = _num(data['saleTotal']) > 0
        ? _num(data['saleTotal'])
        : quantity * salePrice;
    final paidAmount = _num(data['paidAmount']);
    final totalAmount = _num(data['totalAmount']);
    final discountPercent = _num(data['discountPercent']);
    final taxPercent = _num(data['taxPercent'] ?? data['vatPercent']);
    final warnings = <String>[...parse.warnings];

    final values = <String, dynamic>{};

    switch (parse.intent) {
      case SmartAssistantIntent.calculateProfit:
      case SmartAssistantIntent.addProductDraft:
        final profit = saleTotal - totalCost;
        final margin = totalCost > 0 ? (profit / totalCost) * 100 : 0.0;
        values.addAll({
          'quantity': quantity,
          'purchasePrice': purchasePrice,
          'salePrice': salePrice,
          'totalCost': totalCost,
          'expectedRevenue': saleTotal,
          'expectedProfit': profit,
          'profitMargin': margin,
        });
        if (margin < 10 && salePrice > 0 && purchasePrice > 0) {
          warnings.add('Low margin: review pricing before saving.');
        }
        return SmartCalculationResult(
          values: values,
          summary:
              'Expected profit ${_money(profit)} with ${margin.toStringAsFixed(1)}% margin.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateMargin:
        final profit = saleTotal - totalCost;
        final margin = totalCost > 0 ? (profit / totalCost) * 100 : 0.0;
        return SmartCalculationResult(
          values: {'profit': profit, 'profitMargin': margin},
          summary: 'Profit margin is ${margin.toStringAsFixed(1)}%.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateTotalCost:
        return SmartCalculationResult(
          values: {'totalCost': totalCost},
          summary: 'Total cost is ${_money(totalCost)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateSaleTotal:
      case SmartAssistantIntent.calculateWholesaleTotal:
      case SmartAssistantIntent.createSaleDraft:
        return SmartCalculationResult(
          values: {
            'saleTotal': saleTotal,
            'quantity': quantity,
            'unitPrice': salePrice
          },
          summary: 'Sale total is ${_money(saleTotal)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateDiscount:
        final base = totalAmount > 0 ? totalAmount : saleTotal;
        final discount = discountPercent > 0
            ? base * discountPercent / 100
            : _num(data['discountAmount']);
        return SmartCalculationResult(
          values: {'discount': discount, 'netTotal': base - discount},
          summary:
              'Discount is ${_money(discount)}. Net total is ${_money(base - discount)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateTax:
        final base = totalAmount > 0 ? totalAmount : saleTotal;
        final tax = base * taxPercent / 100;
        return SmartCalculationResult(
          values: {
            'tax': tax,
            'totalWithTax': base + tax,
            'taxPercent': taxPercent
          },
          summary:
              'Tax is ${_money(tax)}. Total with tax is ${_money(base + tax)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateRemainingBalance:
      case SmartAssistantIntent.createCustomerPaymentDraft:
        final remaining = _num(data['remainingAmount']) > 0
            ? _num(data['remainingAmount'])
            : (totalAmount > 0 ? totalAmount - paidAmount : 0.0);
        return SmartCalculationResult(
          values: {'paidAmount': paidAmount, 'remainingAmount': remaining},
          summary: 'Remaining balance is ${_money(remaining)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateUnitPrice:
        final unitPrice = quantity > 0 ? totalAmount / quantity : salePrice;
        return SmartCalculationResult(
          values: {'unitPrice': unitPrice},
          summary: 'Unit price is ${_money(unitPrice)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.calculateStockValue:
      case SmartAssistantIntent.inventoryValueQuery:
        return SmartCalculationResult(
          values: {'stockValue': totalCost},
          summary: 'Stock value is ${_money(totalCost)}.',
          warnings: warnings,
        );
      case SmartAssistantIntent.createExpenseDraft:
        final amount = _num(data['amount'] ?? data['totalAmount']);
        return SmartCalculationResult(
          values: {'amount': amount},
          summary: 'Expense draft amount is ${_money(amount)}.',
          warnings: warnings,
        );
      default:
        return SmartCalculationResult(
          values: values,
          summary: parse.intent == SmartAssistantIntent.unknown
              ? 'I could not detect a supported local intent.'
              : 'Preview ready. Confirm before saving.',
          warnings: warnings,
        );
    }
  }

  double _num(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _money(double value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
