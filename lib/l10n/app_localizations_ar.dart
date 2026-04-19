// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Hasoob App';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get appearanceSectionTitle => 'المظهر';

  @override
  String get appearanceSectionDescription =>
      'اختر وضع العرض المناسب لك. سيتم حفظ اختيارك محلياً على هذا الجهاز.';

  @override
  String get themeSystemTitle => 'افتراضي النظام';

  @override
  String get themeSystemSubtitle => 'يتبع إعدادات الجهاز تلقائياً';

  @override
  String get themeLightTitle => 'فاتح';

  @override
  String get themeLightSubtitle => 'مظهر نظيف ومشرق';

  @override
  String get themeDarkTitle => 'داكن';

  @override
  String get themeDarkSubtitle => 'مظهر غني ومريح للعين';

  @override
  String get languageSectionTitle => 'اللغة';

  @override
  String get languageSectionDescription =>
      'اختر لغة التطبيق. يتم تطبيق التغيير فوراً وحفظه على هذا الجهاز.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get helpGuideTitle => 'دليل الاستخدام';

  @override
  String get helpGuideSubtitle =>
      'إرشادات سريعة لفهم الأقسام الأساسية واستخدامها';

  @override
  String get aboutAppTitle => 'حول التطبيق';

  @override
  String get aboutAppSubtitle =>
      'Hasoob App\nإدارة عربية للمخزون والمبيعات والوثائق';
}
