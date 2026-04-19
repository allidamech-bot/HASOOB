import 'package:intl/intl.dart';

import 'app_currency.dart';

class AppFormatters {
  static String currency(
    num value, {
    String? currencyLabel,
    String? localeName,
  }) {
    final formatted = NumberFormat.decimalPatternDigits(
      locale: _localeName(localeName),
      decimalDigits: 2,
    ).format(value);
    final label = AppCurrency.displayLabel(currencyLabel);
    if (label.isEmpty) return formatted;
    return '$formatted $label';
  }

  static String currencyWithCode(
    num value,
    String? currencyCode, {
    String? localeName,
  }) {
    return currency(
      value,
      currencyLabel: currencyCode,
      localeName: localeName,
    );
  }

  static String number(num value, {String? localeName}) {
    return NumberFormat.decimalPattern(_localeName(localeName)).format(value);
  }

  static String decimal(num value) => value.toStringAsFixed(2);

  static String dateTimeString(String? value, {String? localeName}) {
    if (value == null || value.isEmpty) return 'غير متوفر';
    try {
      return DateFormat(
        'yyyy/MM/dd - HH:mm',
        _localeName(localeName),
      ).format(DateTime.parse(value).toLocal());
    } catch (_) {
      return value;
    }
  }

  static String dateString(DateTime value, {String? localeName}) {
    return DateFormat('yyyy/MM/dd', _localeName(localeName)).format(value);
  }

  static String _localeName(String? localeName) {
    final normalized = (localeName ?? Intl.getCurrentLocale()).trim();
    if (normalized.isEmpty) return 'ar';
    return normalized;
  }
}
