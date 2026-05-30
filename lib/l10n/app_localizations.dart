import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hasoob App'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSectionTitle;

  /// No description provided for @appearanceSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the display mode that suits you. Your preference will be saved on this device.'**
  String get appearanceSectionDescription;

  /// No description provided for @themeSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystemTitle;

  /// No description provided for @themeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the device settings automatically'**
  String get themeSystemSubtitle;

  /// No description provided for @themeLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLightTitle;

  /// No description provided for @themeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clean and bright appearance'**
  String get themeLightSubtitle;

  /// No description provided for @themeDarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDarkTitle;

  /// No description provided for @themeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rich and comfortable appearance'**
  String get themeDarkSubtitle;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language. The change is applied immediately and saved on this device.'**
  String get languageSectionDescription;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @helpGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'User guide'**
  String get helpGuideTitle;

  /// No description provided for @helpGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick guidance to understand the main sections and how to use them'**
  String get helpGuideSubtitle;

  /// No description provided for @aboutAppTitle.
  ///
  /// In en, this message translates to:
  /// **'About the app'**
  String get aboutAppTitle;

  /// No description provided for @aboutAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hasoob App\nArabic business management for inventory, sales, and documents'**
  String get aboutAppSubtitle;

  /// No description provided for @dashboardCockpit.
  ///
  /// In en, this message translates to:
  /// **'Financial Intelligence Cockpit'**
  String get dashboardCockpit;

  /// No description provided for @dashboardSecureSession.
  ///
  /// In en, this message translates to:
  /// **'Secure AI Session Active'**
  String get dashboardSecureSession;

  /// No description provided for @dashboardAiGreeting.
  ///
  /// In en, this message translates to:
  /// **'What is the best financial decision today?'**
  String get dashboardAiGreeting;

  /// No description provided for @dashboardAiTitle.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL ADVISOR ACTIVE'**
  String get dashboardAiTitle;

  /// No description provided for @dashboardAiSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Analyzing cash flow, outstanding invoices, obligations, and stock levels to calculate optimal steps.'**
  String get dashboardAiSuggestion;

  /// No description provided for @dashboardHealthScore.
  ///
  /// In en, this message translates to:
  /// **'Financial Health Score'**
  String get dashboardHealthScore;

  /// No description provided for @dashboardHealthExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get dashboardHealthExcellent;

  /// No description provided for @dashboardHealthDesc1.
  ///
  /// In en, this message translates to:
  /// **'SaaS operating efficiency is optimal.'**
  String get dashboardHealthDesc1;

  /// No description provided for @dashboardHealthDesc2.
  ///
  /// In en, this message translates to:
  /// **'Cash flow cover is 85% higher than last month. Current reserves are safe.'**
  String get dashboardHealthDesc2;

  /// No description provided for @dashboardRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'What should I do today?'**
  String get dashboardRecommendationsTitle;

  /// No description provided for @dashboardRec1.
  ///
  /// In en, this message translates to:
  /// **'Follow up invoice #1024 to secure cash reserves before next week.'**
  String get dashboardRec1;

  /// No description provided for @dashboardRec2.
  ///
  /// In en, this message translates to:
  /// **'Reorder top-selling detergent carton (stock count is below 4).'**
  String get dashboardRec2;

  /// No description provided for @dashboardCashFlowPulse.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Pulse'**
  String get dashboardCashFlowPulse;

  /// No description provided for @dashboardCashInflow.
  ///
  /// In en, this message translates to:
  /// **'Cash Inflow'**
  String get dashboardCashInflow;

  /// No description provided for @dashboardCashOutflow.
  ///
  /// In en, this message translates to:
  /// **'Cash Outflow'**
  String get dashboardCashOutflow;

  /// No description provided for @dashboardAiSimulation.
  ///
  /// In en, this message translates to:
  /// **'AI Decision Simulation'**
  String get dashboardAiSimulation;

  /// No description provided for @dashboardSimulationReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get dashboardSimulationReady;

  /// No description provided for @dashboardSimulationScenario.
  ///
  /// In en, this message translates to:
  /// **'Simulation Scenario: Purchase inventory worth 5,000 SAR.'**
  String get dashboardSimulationScenario;

  /// No description provided for @dashboardSimulationResult.
  ///
  /// In en, this message translates to:
  /// **'Result: Liquid cash decreases by 12%. Estimated net profit margin increases by 18% over 30 days.'**
  String get dashboardSimulationResult;

  /// No description provided for @dashboardObligations.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Obligations'**
  String get dashboardObligations;

  /// No description provided for @dashboardObligation1.
  ///
  /// In en, this message translates to:
  /// **'Suppliers Invoices Due'**
  String get dashboardObligation1;

  /// No description provided for @dashboardTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dashboardTomorrow;

  /// No description provided for @dashboardObligation2.
  ///
  /// In en, this message translates to:
  /// **'Employee Salaries'**
  String get dashboardObligation2;

  /// No description provided for @dashboardIn3Days.
  ///
  /// In en, this message translates to:
  /// **'In 3 Days'**
  String get dashboardIn3Days;

  /// No description provided for @dashboardAlertLowStock.
  ///
  /// In en, this message translates to:
  /// **'Risk: Low stock items'**
  String get dashboardAlertLowStock;

  /// No description provided for @dashboardAlertLocalMode.
  ///
  /// In en, this message translates to:
  /// **'Local Mode: Offline database active'**
  String get dashboardAlertLocalMode;

  /// No description provided for @dashboardAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get dashboardAddProduct;

  /// No description provided for @dashboardCreateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get dashboardCreateInvoice;

  /// No description provided for @dashboardAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get dashboardAddCustomer;

  /// No description provided for @dashboardStockThresholds.
  ///
  /// In en, this message translates to:
  /// **'Critical Stock Thresholds'**
  String get dashboardStockThresholds;

  /// No description provided for @dashboardNoLowStock.
  ///
  /// In en, this message translates to:
  /// **'No Low Stock Items'**
  String get dashboardNoLowStock;

  /// No description provided for @dashboardRecentOperations.
  ///
  /// In en, this message translates to:
  /// **'Realtime Customer Operations'**
  String get dashboardRecentOperations;

  /// No description provided for @dashboardNoSalesYet.
  ///
  /// In en, this message translates to:
  /// **'No Sales Yet'**
  String get dashboardNoSalesYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
