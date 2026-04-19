class AppCurrency {
  @Deprecated('Automatic base currency handling has been removed.')
  static const String baseCurrencyCode = '';

  static String? sanitizeLabel(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String displayLabel(String? value) {
    return sanitizeLabel(value) ?? '';
  }

  static bool hasLabel(String? value) {
    return sanitizeLabel(value) != null;
  }

  @Deprecated('Automatic base currency handling has been removed.')
  static bool isBaseCurrency(String? code) => !hasLabel(code);
}
