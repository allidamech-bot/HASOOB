// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hasoob App';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get appearanceSectionDescription =>
      'Choose the display mode that suits you. Your preference will be saved on this device.';

  @override
  String get themeSystemTitle => 'System default';

  @override
  String get themeSystemSubtitle => 'Follow the device settings automatically';

  @override
  String get themeLightTitle => 'Light';

  @override
  String get themeLightSubtitle => 'Clean and bright appearance';

  @override
  String get themeDarkTitle => 'Dark';

  @override
  String get themeDarkSubtitle => 'Rich and comfortable appearance';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSectionDescription =>
      'Choose the app language. The change is applied immediately and saved on this device.';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get helpGuideTitle => 'User guide';

  @override
  String get helpGuideSubtitle =>
      'Quick guidance to understand the main sections and how to use them';

  @override
  String get aboutAppTitle => 'About the app';

  @override
  String get aboutAppSubtitle =>
      'Hasoob App\nArabic business management for inventory, sales, and documents';
}
