import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Radius System
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusXLarge = 32;

  // Font Families
  static const String fontFamilyArabic = 'Cairo';
  static String? get fontFamilyEnglish => GoogleFonts.inter().fontFamily;

  // Premium Palette
  static const Color background = Color(0xFF070B14);
  static const Color surfaceSecondary = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF131D31);
  
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color glowBlue = Color(0x2E3B82F6); // 18% opacity

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color border = Color(0x1F94A3B8); // 12% opacity

  // Light Mode (Refined)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  static LinearGradient premiumGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xF2182235), // rgba(24,34,53,0.95)
      Color(0xF20F172A), // rgba(15,23,42,0.95)
    ],
  );

  static ThemeData darkTheme() {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    
    const colorScheme = ColorScheme.dark(
      primary: accentBlue,
      secondary: accentCyan,
      surface: surfaceSecondary,
      onSurface: textPrimary,
      error: danger,
      outline: border,
    );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: accentBlue,
      fontFamily: fontFamilyArabic, // Base for Arabic, Inter for English via textTheme
      
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      inputDecorationTheme: _inputThemeDark(),
      
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: accentBlue.withValues(alpha: 0.2),
        secondarySelectedColor: accentBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surfaceElevated,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          side: const BorderSide(color: border),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: accentBlue.withValues(alpha: 0.1),
        height: 80,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? textPrimary : textSecondary,
          );
        }),
      ),
    );

    return _applyTypography(theme, textPrimary, textSecondary);
  }

  static ThemeData lightTheme() {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accentBlue,
        secondary: accentCyan,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      scaffoldBackgroundColor: lightBackground,
      fontFamily: fontFamilyArabic,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: lightBorder),
        ),
      ),
    );
    return _applyTypography(theme, lightTextPrimary, lightTextSecondary);
  }

  static ThemeData _applyTypography(ThemeData base, Color primary, Color secondary) {
    final textTheme = base.textTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -1.0,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }

  static InputDecorationTheme _inputThemeDark() => InputDecorationTheme(
    filled: true,
    fillColor: surfaceSecondary,
    contentPadding: const EdgeInsets.all(20),
    hintStyle: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w400),
    labelStyle: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w500),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: accentBlue, width: 2),
    ),
  );

  // Compatibility Aliases (for existing widgets)
  static const Color accent = accentBlue;
  static const Color accentSoft = accentCyan;
  static const Color surface = surfaceSecondary;
  static const Color surfaceAlt = surfaceElevated;
  static const Color surfaceMuted = surfaceElevated;
  static const Color outlineDark = border;
  static const Color outlineLight = lightBorder;
  static const Color brandBlue = accentBlue;
  static const Color glowCyan = Color(0x1A22D3EE); // 10% opacity cyan
  static const Color info = accentBlue;
  static const Color lightSurfaceMuted = Color(0xFFF1F5F9);
  static const String fontFamily = 'Inter';

  // Helper getters
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color surfaceFor(BuildContext context) => isDark(context) ? surfaceSecondary : lightSurface;
  static Color surfaceAltFor(BuildContext context) => isDark(context) ? surfaceElevated : lightSurfaceMuted;
  static Color backgroundFor(BuildContext context) => isDark(context) ? background : lightBackground;
  static Color borderFor(BuildContext context) => isDark(context) ? border : lightBorder;
  static Color textSecondaryFor(BuildContext context) => isDark(context) ? textSecondary : lightTextSecondary;


  static List<BoxShadow> softShadow(BuildContext context) => [
    BoxShadow(
      color: isDark(context) ? Colors.black.withValues(alpha: 0.3) : accentBlue.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}


