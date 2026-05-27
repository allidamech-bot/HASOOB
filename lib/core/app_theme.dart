import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Radius System
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  // Font Families
  static const String fontFamilyArabic = 'Cairo';
  static String? get fontFamilyEnglish => GoogleFonts.inter().fontFamily;

  // Premium Palette
  static const Color background = Color(0xFF0F172A);
  static const Color backgroundDeep = Color(0xFF090D16);
  static const Color surfaceSecondary = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF334155);
  
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentAmber = Color(0xFFF59E0B);
  
  static const Color glowBlue = Color(0x2E3B82F6); // 18% opacity
  static const Color glowBlueStrong = Color(0x403B82F6); // 25% opacity
  static const Color glowViolet = Color(0x2E8B5CF6); // 18% opacity

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color border = Color(0x1F94A3B8); // 12% opacity

  // Light Mode (Refined)
  static const Color lightBackground = Color(0xFFF9F7F4);
  static const Color lightBackgroundDeep = Color(0xFFF1EFEA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // ─────────────────────────────────────────────
  // AI System Colors
  // ─────────────────────────────────────────────
  static const Color aiDeep = Color(0xFF080B14);
  static const Color aiNavy = Color(0xFF0A0D1A);
  static const Color aiCard = Color(0xFF0F1629);
  static const Color aiCardElevated = Color(0xFF141D35);
  static const Color aiCardBorder = Color(0xFF1E2D50);

  static const Color aiBlue = Color(0xFF00D4FF);
  static const Color aiBlueGlow = Color(0x2500D4FF);
  static const Color aiBlueGlowStrong = Color(0x4000D4FF);
  static const Color aiGold = Color(0xFFD4AF37);
  static const Color aiGoldGlow = Color(0x25D4AF37);
  static const Color aiGreen = Color(0xFF10B981);
  static const Color aiGreenGlow = Color(0x2510B981);
  static const Color aiRed = Color(0xFFEF4444);

  static const Color aiTextPrimary = Color(0xFFE8F4FD);
  static const Color aiTextSecondary = Color(0xFF6B8AAD);
  static const Color aiTextMuted = Color(0xFF3D5273);

  // ─────────────────────────────────────────────
  // AI Gradients
  // ─────────────────────────────────────────────
  static const LinearGradient aiHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF080B14),
      Color(0xFF0A0D1A),
      Color(0xFF060810),
    ],
  );

  static const LinearGradient aiBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
  );

  static const LinearGradient aiGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4AF37), Color(0xFFF59E0B)],
  );

  // ─────────────────────────────────────────────
  // AI Helper Methods
  // ─────────────────────────────────────────────
  static BoxDecoration glassCard({Color? borderColor, Color? glowColor}) {
    return BoxDecoration(
      color: const Color(0xFF0F1629).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: borderColor ?? const Color(0xFF1E2D50),
        width: 1,
      ),
      boxShadow: glowColor != null
          ? [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  static BoxDecoration aiButtonDecoration({required Color color}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withValues(alpha: 0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Legacy gradient (kept for compatibility)
  // ─────────────────────────────────────────────
  static LinearGradient premiumGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF233045),
      Color(0xFF1E293B),
    ],
  );

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: aiBlue,
      secondary: accentCyan,
      surface: aiCard,
      onSurface: aiTextPrimary,
      error: aiRed,
      outline: aiCardBorder,
    );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: aiDeep,
      canvasColor: aiDeep,
      primaryColor: aiBlue,
      fontFamily: fontFamilyArabic, // Base for Arabic, Inter for English via textTheme
      
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: aiTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: aiTextPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: aiCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: aiCardBorder, width: 1),
        ),
      ),

      inputDecorationTheme: _inputThemeDark(),
      
      chipTheme: ChipThemeData(
        backgroundColor: aiCardElevated,
        selectedColor: aiBlue.withValues(alpha: 0.2),
        secondarySelectedColor: aiBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        side: const BorderSide(color: aiCardBorder),
        labelStyle: GoogleFonts.inter(
          color: aiTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: aiCardBorder,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: aiBlue,
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
          foregroundColor: aiTextPrimary,
          side: const BorderSide(color: aiCardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: aiCardElevated,
          foregroundColor: aiTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          side: const BorderSide(color: aiCardBorder),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: aiNavy,
        indicatorColor: aiBlue.withValues(alpha: 0.1),
        height: 80,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? aiTextPrimary : aiTextSecondary,
          );
        }),
      ),
    );

    return _applyTypography(theme, aiTextPrimary, aiTextSecondary);
  }

  static ThemeData lightTheme() {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
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
    fillColor: aiCardElevated,
    contentPadding: const EdgeInsets.all(20),
    hintStyle: GoogleFonts.inter(color: aiTextMuted, fontWeight: FontWeight.w400),
    labelStyle: GoogleFonts.inter(color: aiTextSecondary, fontWeight: FontWeight.w500),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: aiCardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: aiCardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: aiBlue, width: 2),
    ),
  );

  // ─────────────────────────────────────────────
  // Compatibility Layer (Maintained for existing screens)
  // ─────────────────────────────────────────────
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

  // Helper Methods (Maintained for legacy screens)
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color surfaceFor(BuildContext context) => isDark(context) ? aiCard : lightSurface;
  static Color surfaceAltFor(BuildContext context) => isDark(context) ? aiCardElevated : lightSurfaceMuted;
  static Color backgroundFor(BuildContext context) => isDark(context) ? aiDeep : lightBackground;
  static Color borderFor(BuildContext context) => isDark(context) ? aiCardBorder : lightBorder;
  static Color textSecondaryFor(BuildContext context) => isDark(context) ? aiTextSecondary : lightTextSecondary;

  static List<BoxShadow> softShadow(BuildContext context) => [
    BoxShadow(
      color: isDark(context) ? Colors.black.withValues(alpha: 0.3) : accentBlue.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static LinearGradient commandGradient(BuildContext context) {
    return isDark(context)
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1526),
              Color(0xFF0A0D1A),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEFF6FF), // soft blue
              Color(0xFFE0F2FE), // soft cyan
            ],
          );
  }

  static Color navBarBackground(BuildContext context) => isDark(context) ? aiNavy : lightBackgroundDeep;

  static List<BoxShadow> shadowStrong(BuildContext context) => [
    BoxShadow(
      color: isDark(context) ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowGlow(BuildContext context, Color glowColor) => [
    BoxShadow(
      color: glowColor.withValues(alpha: 0.25),
      blurRadius: 12,
      spreadRadius: 2,
      offset: const Offset(0, 0),
    ),
  ];

  static List<BoxShadow> haloShadow(Color glowColor) => [
    BoxShadow(
      color: glowColor.withValues(alpha: 0.2),
      blurRadius: 24,
      spreadRadius: 4,
    ),
  ];
}


