class Product {
  final String id;
  final String name;
  final String unit;
  final double purchasePrice;
  final double extraCosts;
  final double sellingPrice;
  final int stockQty;
  final int lowStockThreshold;
  final String? barcode;

  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    this.extraCosts = 0.0,
    this.stockQty = 0,
    this.lowStockThreshold = 5,
    this.barcode,
  });

  double get landedCost => purchasePrice + extraCosts;
  double get netProfit => sellingPrice - landedCost;
  double get totalStockValue => landedCost * stockQty;
  double get expectedRevenue => sellingPrice * stockQty;
  double get totalExpectedProfit => netProfit * stockQty;

  bool get isOutOfStock => stockQty <= 0;
  bool get isLowStock => stockQty <= lowStockThreshold;

  Product copyWith({
    String? id,
    String? name,
    String? unit,
    double? purchasePrice,
    double? extraCosts,
    double? sellingPrice,
    int? stockQty,
    int? lowStockThreshold,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      extraCosts: extraCosts ?? this.extraCosts,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      barcode: barcode ?? this.barcode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'purchase_price': purchasePrice,
      'extra_costs': extraCosts,
      'selling_price': sellingPrice,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'barcode': barcode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: (map['name'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString(),
      purchasePrice: _toDouble(map['purchase_price']),
      extraCosts: _toDouble(map['extra_costs']),
      sellingPrice: _toDouble(map['selling_price']),
      stockQty: _toInt(map['stock_qty']),
      lowStockThreshold: _toInt(map['low_stock_threshold'], fallback: 5),
      barcode: map['barcode']?.toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }
}
