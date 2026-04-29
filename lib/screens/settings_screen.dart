import 'package:flutter/material.dart';

import '../core/app_locale_controller.dart';
import '../core/app_theme.dart';
import '../core/app_theme_controller.dart';
import '../l10n/app_localizations.dart';
import 'help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeControllerScope.of(context);
    final localeController = AppLocaleControllerScope.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedLocaleCode =
        (localeController.locale ?? Localizations.localeOf(context)).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appearanceSectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appearanceSectionDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _themeOption(
                    context,
                    controller: controller,
                    mode: ThemeMode.system,
                    icon: Icons.brightness_auto_rounded,
                    title: l10n.themeSystemTitle,
                    subtitle: l10n.themeSystemSubtitle,
                  ),
                  const SizedBox(height: 10),
                  _themeOption(
                    context,
                    controller: controller,
                    mode: ThemeMode.light,
                    icon: Icons.light_mode_rounded,
                    title: l10n.themeLightTitle,
                    subtitle: l10n.themeLightSubtitle,
                  ),
                  const SizedBox(height: 10),
                  _themeOption(
                    context,
                    controller: controller,
                    mode: ThemeMode.dark,
                    icon: Icons.dark_mode_rounded,
                    title: l10n.themeDarkTitle,
                    subtitle: l10n.themeDarkSubtitle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.languageSectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.languageSectionDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _languageOption(
                    context,
                    localeController: localeController,
                    localeCode: 'ar',
                    currentLocaleCode: selectedLocaleCode,
                    title: l10n.languageArabic,
                  ),
                  const SizedBox(height: 10),
                  _languageOption(
                    context,
                    localeController: localeController,
                    localeCode: 'en',
                    currentLocaleCode: selectedLocaleCode,
                    title: l10n.languageEnglish,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(
                    l10n.helpGuideTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    l10n.helpGuideSubtitle,
                    style: TextStyle(color: AppTheme.textSecondaryFor(context)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  },
                ),
                Divider(color: AppTheme.borderFor(context), height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(
                    l10n.aboutAppTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    l10n.aboutAppSubtitle,
                    style: TextStyle(color: AppTheme.textSecondaryFor(context)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    BuildContext context, {
    required AppThemeController controller,
    required ThemeMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = controller.themeMode == mode;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: () => controller.updateThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.10)
              : AppTheme.surfaceAltFor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.35)
                : AppTheme.borderFor(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.16)
                    : AppTheme.surfaceFor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppTheme.accent
                    : Theme.of(context).iconTheme.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryFor(context),
                    ),
                  ),
                ],
              ),
            ),
            // ignore: deprecated_member_use
            Radio<ThemeMode>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: controller.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  controller.updateThemeMode(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(
    BuildContext context, {
    required AppLocaleController localeController,
    required String localeCode,
    required String currentLocaleCode,
    required String title,
  }) {
    final isSelected = currentLocaleCode == localeCode;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: () => localeController.updateLocale(Locale(localeCode)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.10)
              : AppTheme.surfaceAltFor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.35)
                : AppTheme.borderFor(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.16)
                    : AppTheme.surfaceFor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.language_rounded,
                color: isSelected
                    ? AppTheme.accent
                    : Theme.of(context).iconTheme.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            // ignore: deprecated_member_use
            Radio<String>(
              value: localeCode,
              // ignore: deprecated_member_use
              groupValue: currentLocaleCode,
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  localeController.updateLocale(Locale(value));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
