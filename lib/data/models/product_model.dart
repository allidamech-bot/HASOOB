import 'dart:convert';

class ProductModel {
  final String id;
  final String businessId;
  final String name;
  final String unit;
  final double purchasePrice;
  final double extraCosts;
  final double sellingPrice;
  final int stockQty;
  final int lowStockThreshold;
  final String? barcode;

  // Premium Features - Basic Info
  final String? sku;
  final String? qrCode;
  final String? category;
  final String? brand;
  final String? supplier;
  final String? description;
  final String? imagePath;
  final List<String> galleryPaths;

  // Premium Features - Pricing
  final double wholesalePrice;
  final double discountPrice;
  final double vatPercentage;
  final double taxAmount;

  // Premium Features - Inventory
  final int reservedQty;
  final int minStockAlert;
  final int maxStock;
  final String? warehouse;
  final String? shelfLocation;
  final String? branchAssignment;
  final String status; // active, draft, archived

  // Premium Features - Dates
  final DateTime? purchaseDate;
  final DateTime? productionDate;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Premium Features - Attributes
  final String? color;
  final String? size;
  final double weight;
  final String? dimensions;
  final String? material;
  final String? modelNumber;
  final String? serialNumber;
  final String? originCountry;
  final String? internalNotes;

  // Premium Features - Selling Options
  final bool isSellable;
  final bool isDiscountAllowed;
  final bool isTrackingEnabled;
  final bool showInReports;
  final bool requiresSerial;
  final bool requiresExpiry;
  final bool isFeatured;
  final bool isHidden;

  const ProductModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    this.extraCosts = 0.0,
    this.stockQty = 0,
    this.lowStockThreshold = 5,
    this.barcode,
    this.sku,
    this.qrCode,
    this.category,
    this.brand,
    this.supplier,
    this.description,
    this.imagePath,
    this.galleryPaths = const [],
    this.wholesalePrice = 0.0,
    this.discountPrice = 0.0,
    this.vatPercentage = 0.0,
    this.taxAmount = 0.0,
    this.reservedQty = 0,
    this.minStockAlert = 5,
    this.maxStock = 999999,
    this.warehouse,
    this.shelfLocation,
    this.branchAssignment,
    this.status = 'active',
    this.purchaseDate,
    this.productionDate,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
    this.color,
    this.size,
    this.weight = 0.0,
    this.dimensions,
    this.material,
    this.modelNumber,
    this.serialNumber,
    this.originCountry,
    this.internalNotes,
    this.isSellable = true,
    this.isDiscountAllowed = true,
    this.isTrackingEnabled = true,
    this.showInReports = true,
    this.requiresSerial = false,
    this.requiresExpiry = false,
    this.isFeatured = false,
    this.isHidden = false,
  });

  double get landedCost => purchasePrice + extraCosts;
  double get netProfit => sellingPrice - landedCost;
  double get totalStockValue => landedCost * stockQty;
  double get expectedRevenue => sellingPrice * stockQty;
  double get totalExpectedProfit => netProfit * stockQty;
  double get marginPercentage => landedCost > 0 ? (netProfit / landedCost) * 100 : 0.0;

  bool get isOutOfStock => stockQty <= 0;
  bool get isLowStock => stockQty <= lowStockThreshold;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  ProductModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? unit,
    double? purchasePrice,
    double? extraCosts,
    double? sellingPrice,
    int? stockQty,
    int? lowStockThreshold,
    String? barcode,
    String? sku,
    String? qrCode,
    String? category,
    String? brand,
    String? supplier,
    String? description,
    String? imagePath,
    List<String>? galleryPaths,
    double? wholesalePrice,
    double? discountPrice,
    double? vatPercentage,
    double? taxAmount,
    int? reservedQty,
    int? minStockAlert,
    int? maxStock,
    String? warehouse,
    String? shelfLocation,
    String? branchAssignment,
    String? status,
    DateTime? purchaseDate,
    DateTime? productionDate,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
    String? size,
    double? weight,
    String? dimensions,
    String? material,
    String? modelNumber,
    String? serialNumber,
    String? originCountry,
    String? internalNotes,
    bool? isSellable,
    bool? isDiscountAllowed,
    bool? isTrackingEnabled,
    bool? showInReports,
    bool? requiresSerial,
    bool? requiresExpiry,
    bool? isFeatured,
    bool? isHidden,
  }) {
    return ProductModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      extraCosts: extraCosts ?? this.extraCosts,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      qrCode: qrCode ?? this.qrCode,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      supplier: supplier ?? this.supplier,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      galleryPaths: galleryPaths ?? this.galleryPaths,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      discountPrice: discountPrice ?? this.discountPrice,
      vatPercentage: vatPercentage ?? this.vatPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      reservedQty: reservedQty ?? this.reservedQty,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      maxStock: maxStock ?? this.maxStock,
      warehouse: warehouse ?? this.warehouse,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      branchAssignment: branchAssignment ?? this.branchAssignment,
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      productionDate: productionDate ?? this.productionDate,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      material: material ?? this.material,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      originCountry: originCountry ?? this.originCountry,
      internalNotes: internalNotes ?? this.internalNotes,
      isSellable: isSellable ?? this.isSellable,
      isDiscountAllowed: isDiscountAllowed ?? this.isDiscountAllowed,
      isTrackingEnabled: isTrackingEnabled ?? this.isTrackingEnabled,
      showInReports: showInReports ?? this.showInReports,
      requiresSerial: requiresSerial ?? this.requiresSerial,
      requiresExpiry: requiresExpiry ?? this.requiresExpiry,
      isFeatured: isFeatured ?? this.isFeatured,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'unit': unit,
      'purchase_price': purchasePrice,
      'extra_costs': extraCosts,
      'selling_price': sellingPrice,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'barcode': barcode,
      'sku': sku,
      'qr_code': qrCode,
      'category': category,
      'brand': brand,
      'supplier': supplier,
      'description': description,
      'image_path': imagePath,
      'gallery_paths': jsonEncode(galleryPaths),
      'wholesale_price': wholesalePrice,
      'discount_price': discountPrice,
      'vat_percentage': vatPercentage,
      'tax_amount': taxAmount,
      'reserved_qty': reservedQty,
      'min_stock_alert': minStockAlert,
      'max_stock': maxStock,
      'warehouse': warehouse,
      'shelf_location': shelfLocation,
      'branch_assignment': branchAssignment,
      'status': status,
      'purchase_date': purchaseDate?.toIso8601String(),
      'production_date': productionDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'color': color,
      'size': size,
      'weight': weight,
      'dimensions': dimensions,
      'material': material,
      'model_number': modelNumber,
      'serial_number': serialNumber,
      'origin_country': originCountry,
      'internal_notes': internalNotes,
      'is_sellable': isSellable ? 1 : 0,
      'is_discount_allowed': isDiscountAllowed ? 1 : 0,
      'is_tracking_enabled': isTrackingEnabled ? 1 : 0,
      'show_in_reports': showInReports ? 1 : 0,
      'requires_serial': requiresSerial ? 1 : 0,
      'requires_expiry': requiresExpiry ? 1 : 0,
      'is_featured': isFeatured ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      businessId: map['businessId']?.toString() ?? '',
      name: (map['name'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString(),
      purchasePrice: _toDouble(map['purchase_price']),
      extraCosts: _toDouble(map['extra_costs']),
      sellingPrice: _toDouble(map['selling_price'] ?? map['price']),
      stockQty: _toInt(map['stock_qty'] ?? map['quantity']),
      lowStockThreshold: _toInt(map['low_stock_threshold'], fallback: 5),
      barcode: map['barcode']?.toString(),
      sku: map['sku']?.toString(),
      qrCode: map['qr_code']?.toString(),
      category: map['category']?.toString(),
      brand: map['brand']?.toString(),
      supplier: map['supplier']?.toString(),
      description: map['description']?.toString(),
      imagePath: map['image_path']?.toString(),
      galleryPaths: _toStringList(map['gallery_paths']),
      wholesalePrice: _toDouble(map['wholesale_price']),
      discountPrice: _toDouble(map['discount_price']),
      vatPercentage: _toDouble(map['vat_percentage']),
      taxAmount: _toDouble(map['tax_amount']),
      reservedQty: _toInt(map['reserved_qty']),
      minStockAlert: _toInt(map['min_stock_alert'], fallback: 5),
      maxStock: _toInt(map['max_stock'], fallback: 999999),
      warehouse: map['warehouse']?.toString(),
      shelfLocation: map['shelf_location']?.toString(),
      branchAssignment: map['branch_assignment']?.toString(),
      status: map['status']?.toString() ?? 'active',
      purchaseDate: _toDateTime(map['purchase_date']),
      productionDate: _toDateTime(map['production_date']),
      expiryDate: _toDateTime(map['expiry_date']),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
      color: map['color']?.toString(),
      size: map['size']?.toString(),
      weight: _toDouble(map['weight']),
      dimensions: map['dimensions']?.toString(),
      material: map['material']?.toString(),
      modelNumber: map['model_number']?.toString(),
      serialNumber: map['serial_number']?.toString(),
      originCountry: map['origin_country']?.toString(),
      internalNotes: map['internal_notes']?.toString(),
      isSellable: _toBool(map['is_sellable'], fallback: true),
      isDiscountAllowed: _toBool(map['is_discount_allowed'], fallback: true),
      isTrackingEnabled: _toBool(map['is_tracking_enabled'], fallback: true),
      showInReports: _toBool(map['show_in_reports'], fallback: true),
      requiresSerial: _toBool(map['requires_serial'], fallback: false),
      requiresExpiry: _toBool(map['requires_expiry'], fallback: false),
      isFeatured: _toBool(map['is_featured'], fallback: false),
      isHidden: _toBool(map['is_hidden'], fallback: false),
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

  static bool _toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;
    return value.toString().toLowerCase() == 'true' || value.toString() == '1';
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    try {
      final decoded = jsonDecode(value.toString());
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
