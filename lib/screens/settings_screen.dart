import 'package:flutter/material.dart';

import '../core/app_locale_controller.dart';
import '../core/app_theme.dart';
import '../core/app_theme_controller.dart';
import '../l10n/app_localizations.dart';
import '../core/app_copy.dart';
import '../widgets/premium/premium_card.dart';
import '../widgets/ai_design_system.dart';
import 'help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeControllerScope.of(context);
    final localeController = AppLocaleControllerScope.of(context);
    final copy = AppCopy.of(context);
    final isEnglish = copy.isEnglish;

    final selectedLocaleCode =
        (localeController.locale ?? Localizations.localeOf(context)).languageCode;

    return Scaffold(
      backgroundColor: AppTheme.aiDeep,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AiPageHeader(
              title: isEnglish ? 'Settings' : 'الإعدادات',
              subtitle: isEnglish ? 'Customize your experience' : 'تخصيص تجربتك وإعدادات التطبيق',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    title: isEnglish ? 'Appearance' : 'المظهر',
                    icon: Icons.palette_rounded,
                    children: [
                      ThemeOption(
                        context,
                        controller: controller,
                        mode: ThemeMode.system,
                        icon: Icons.brightness_auto_rounded,
                        title: isEnglish ? 'System Theme' : 'المظهر التلقائي',
                        subtitle: isEnglish ? 'Follow system setting' : 'يتبع إعدادات النظام',
                      ),
                      const SizedBox(height: 12),
                      ThemeOption(
                        context,
                        controller: controller,
                        mode: ThemeMode.light,
                        icon: Icons.light_mode_rounded,
                        title: isEnglish ? 'Light Mode' : 'المظهر الفاتح',
                        subtitle: isEnglish ? 'Light background' : 'خلفية فاتحة',
                      ),
                      const SizedBox(height: 12),
                      ThemeOption(
                        context,
                        controller: controller,
                        mode: ThemeMode.dark,
                        icon: Icons.dark_mode_rounded,
                        title: isEnglish ? 'Dark Mode' : 'المظهر الداكن',
                        subtitle: isEnglish ? 'Luxury midnight theme' : 'مظهر ليل نايت ليل',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: isEnglish ? 'Language' : 'اللغة',
                    icon: Icons.language_rounded,
                    children: [
                      LanguageOption(
                        context,
                        localeController: localeController,
                        localeCode: 'ar',
                        currentLocaleCode: selectedLocaleCode,
                        title: isEnglish ? 'العربية' : 'Arabic',
                      ),
                      const SizedBox(height: 12),
                      LanguageOption(
                        context,
                        localeController: localeController,
                        localeCode: 'en',
                        currentLocaleCode: selectedLocaleCode,
                        title: isEnglish ? 'English' : 'English',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: isEnglish ? 'System' : 'النظام',
                    icon: Icons.sync_alt_rounded,
                    children: [
                      AiDataRow(
                        leading: const AiIconContainer(
                          icon: Icons.sync_rounded,
                          color: AppTheme.aiBlue,
                        ),
                        title: copy.t('syncCenter'),
                        subtitle: copy.t('syncCenterSubtitle'),
                        onTap: () => Navigator.pushNamed(context, '/sync'),
                      ),
                      const SizedBox(height: 12),
                      AiDataRow(
                        leading: const AiIconContainer(
                          icon: Icons.help_outline_rounded,
                          color: AppTheme.aiGreen,
                        ),
                        title: AppLocalizations.of(context)!.helpGuideTitle,
                        subtitle: AppLocalizations.of(context)!.helpGuideSubtitle,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HelpScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      border: Border.all(
        color: AppTheme.aiGold.withValues(alpha: 0.2),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.aiBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.aiBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.aiTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class ThemeOption extends StatelessWidget {
  final BuildContext context;
  final AppThemeController controller;
  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;

  const ThemeOption(
    this.context, {
    super.key,
    required this.controller,
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.themeMode == mode;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => controller.updateThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.aiGold.withValues(alpha: 0.08)
              : AppTheme.aiCardElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.aiGold.withValues(alpha: 0.35)
                : AppTheme.aiCardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.aiGold.withValues(alpha: 0.15)
                    : AppTheme.aiCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.aiGold : AppTheme.aiTextSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.aiGold : AppTheme.aiTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.aiGold, size: 20)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: AppTheme.aiTextMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class LanguageOption extends StatelessWidget {
  final BuildContext context;
  final AppLocaleController localeController;
  final String localeCode;
  final String currentLocaleCode;
  final String title;

  const LanguageOption(
    this.context, {
    super.key,
    required this.localeController,
    required this.localeCode,
    required this.currentLocaleCode,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentLocaleCode == localeCode;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => localeController.updateLocale(Locale(localeCode)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.aiGold.withValues(alpha: 0.08)
              : AppTheme.aiCardElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.aiGold.withValues(alpha: 0.35)
                : AppTheme.aiCardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.aiGold.withValues(alpha: 0.15)
                    : AppTheme.aiCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: AppTheme.aiTextSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppTheme.aiGold : AppTheme.aiTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.aiGold, size: 20)
            else
              const Icon(Icons.radio_button_unchecked_rounded, color: AppTheme.aiTextMuted, size: 20),
          ],
        ),
      ),
    );
  }
}