enum AiWorkflowType {
  purchase,
  sale,
  pricing,
  inventoryAdjustment,
  customerBalanceInquiry,
  supplierInquiry,
}

class AiWorkflowField {
  static const product = 'product';
  static const quantity = 'quantity';
  static const cost = 'cost';
  static const sellingPrice = 'sellingPrice';
  static const customer = 'customer';
  static const supplier = 'supplier';
  static const adjustmentQuantity = 'adjustmentQuantity';

  static String label(String field) {
    switch (field) {
      case product:
        return 'Product';
      case quantity:
        return 'Quantity';
      case cost:
        return 'Unit cost';
      case sellingPrice:
        return 'Selling price';
      case customer:
        return 'Customer';
      case supplier:
        return 'Supplier';
      case adjustmentQuantity:
        return 'Adjustment quantity';
      default:
        return field;
    }
  }
}
