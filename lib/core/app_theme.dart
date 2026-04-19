import 'package:flutter/material.dart';

class AppTheme {
  static const double radiusSmall = 14;
  static const double radiusMedium = 18;
  static const double radiusLarge = 24;
  static const double radiusXLarge = 28;

  static const String fontFamily = 'Cairo';

  static const Color accent = Color(0xFF2F80ED);
  static const Color accentSoft = Color(0xFF60A5FA);
  static const Color accentLight = Color(0xFFDCEBFF);

  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF141B2D);
  static const Color surfaceAlt = Color(0xFF1B2438);
  static const Color surfaceMuted = Color(0xFF24314A);
  static const Color outlineDark = Color(0xFF334155);

  static const Color lightBackground = Color(0xFFF5F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF8FBFF);
  static const Color lightSurfaceMuted = Color(0xFFE7EEF7);
  static const Color outlineLight = Color(0xFFD4E0EF);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color brandBlue = Color(0xFF0D3B82);
  static const Color lightDivider = Color(0xFFDCE6F2);

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF2F80ED),
      secondary: Color(0xFF60A5FA),
      surface: surface,
      onSurface: textPrimary,
      error: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: accent,
      fontFamily: fontFamily,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceAlt,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: _inputThemeDark(),
      navigationBarTheme: _navThemeDark(),
      chipTheme: _chipThemeDark().copyWith(
        checkmarkColor: accentSoft,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 0.8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        iconColor: accentSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );

    return _common(base, textPrimary, textSecondary, true);
  }

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      primary: accent,
      secondary: accentSoft,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      error: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightBackground,
      primaryColor: accent,
      fontFamily: fontFamily,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: lightSurface,
        contentTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: lightTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: lightSurface,
        margin: EdgeInsets.zero,
        shadowColor: brandBlue.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: outlineLight, width: 1.0),
        ),
      ),
      inputDecorationTheme: _inputThemeLight(),
      navigationBarTheme: _navThemeLight(),
      chipTheme: _chipThemeLight().copyWith(
        checkmarkColor: accent,
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 0.9,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lightSurface,
        modalBackgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        iconColor: accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      iconTheme: const IconThemeData(
        color: lightTextPrimary,
      ),
      primaryIconTheme: const IconThemeData(
        color: lightTextPrimary,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(lightSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
              side: const BorderSide(color: outlineLight),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _inputThemeLight(),
        textStyle: const TextStyle(
          color: lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(lightSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
              side: const BorderSide(color: outlineLight),
            ),
          ),
        ),
      ),
    );

    return _common(base, lightTextPrimary, lightTextSecondary, false);
  }

  static ThemeData _common(
    ThemeData base,
    Color textColor,
    Color mutedTextColor,
    bool isDark,
  ) {
    final textTheme = base.textTheme
        .apply(
          fontFamily: fontFamily,
          bodyColor: textColor,
          displayColor: textColor,
        )
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
          ),
          displayMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
          titleLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: mutedTextColor,
          ),
          labelLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: mutedTextColor,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : outlineLight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? accentSoft : accent,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        circularTrackColor:
            isDark ? Colors.white.withValues(alpha: 0.08) : lightSurfaceMuted,
      ),
      switchTheme: const SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static InputDecorationTheme _inputThemeDark() => InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          color: textSecondary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
        helperStyle: const TextStyle(
          color: textSecondary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        floatingLabelStyle: const TextStyle(
          color: accentSoft,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accentSoft, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger, width: 1.3),
        ),
      );

  static InputDecorationTheme _inputThemeLight() => InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          color: lightTextSecondary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: const TextStyle(
          color: lightTextSecondary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: lightTextSecondary,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        floatingLabelStyle: const TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        prefixIconColor: lightTextSecondary,
        suffixIconColor: lightTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: outlineLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accent, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      );

  static NavigationBarThemeData _navThemeDark() => NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.16),
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? accentSoft
                : textSecondary,
          ),
        ),
      );

  static NavigationBarThemeData _navThemeLight() => NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: accent.withValues(alpha: 0.14),
        height: 76,
        surfaceTintColor: Colors.transparent,
        shadowColor: brandBlue.withValues(alpha: 0.08),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? lightTextPrimary
                : lightTextSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? accent
                : lightTextSecondary,
          ),
        ),
      );

  static ChipThemeData _chipThemeDark() => ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: accent.withValues(alpha: 0.18),
        disabledColor: surfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      );

  static ChipThemeData _chipThemeLight() => ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: accent.withValues(alpha: 0.12),
        disabledColor: lightSurfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: const BorderSide(color: outlineLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
        ),
      );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundFor(BuildContext context) =>
      isDark(context) ? background : lightBackground;

  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? surface : lightSurface;

  static Color surfaceAltFor(BuildContext context) =>
      isDark(context) ? surfaceAlt : lightSurfaceAlt;

  static Color mutedSurfaceFor(BuildContext context) =>
      isDark(context) ? surfaceMuted : lightSurfaceMuted;

  static Color borderFor(BuildContext context) =>
      isDark(context) ? Colors.white.withValues(alpha: 0.08) : outlineLight;

  static Color textSecondaryFor(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;

  static List<BoxShadow> softShadow(BuildContext context) => [
        BoxShadow(
          color: isDark(context)
              ? Colors.black.withValues(alpha: 0.24)
              : brandBlue.withValues(alpha: 0.08),
          blurRadius: isDark(context) ? 30 : 24,
          offset: const Offset(0, 12),
        ),
      ];
}
