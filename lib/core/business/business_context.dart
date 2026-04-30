class BusinessContext {
  static const String fallbackBusinessId = 'demo-business';

  static String resolveBusinessId([String? businessId]) {
    if (businessId != null && businessId.trim().isNotEmpty) {
      return businessId;
    }
    return fallbackBusinessId;
  }
}
