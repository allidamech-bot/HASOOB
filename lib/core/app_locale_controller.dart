import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._(this._locale);

  static const _preferenceKey = 'selected_locale_code';

  Locale? _locale;

  Locale? get locale => _locale;

  static Future<AppLocaleController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_preferenceKey);
    final locale = (code == null || code.isEmpty) ? null : Locale(code);
    return AppLocaleController._(locale);
  }

  Future<void> updateLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;

    final preferences = await SharedPreferences.getInstance();
    if (locale == null) {
      await preferences.remove(_preferenceKey);
    } else {
      await preferences.setString(_preferenceKey, locale.languageCode);
    }

    notifyListeners();
  }
}

class AppLocaleControllerScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleControllerScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLocaleControllerScope>();
    assert(scope != null, 'AppLocaleControllerScope not found in context');
    return scope!.notifier!;
  }
}
