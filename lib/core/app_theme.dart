import 'package:flutter/material.dart';

// ─── Dynamic Color Palette ────────────────────────────────────────────────────
// Colors are mutable so applyDark() / applyLight() can swap the whole palette
// at runtime without rebuilding every widget class.

class AppColors {
  // Background gradient stops
  static Color bg1 = const Color(0xFF080D1E);
  static Color bg2 = const Color(0xFF0D1840);
  static Color bg3 = const Color(0xFF120A34);

  // Ambient orbs
  static Color orb1 = const Color(0x352563EB);
  static Color orb2 = const Color(0x287C3AED);
  static Color orb3 = const Color(0x1A0EA5E9);

  // Glass surfaces
  static Color glassBg           = const Color(0x14FFFFFF);
  static Color glassBgCard       = const Color(0x10FFFFFF);
  static Color glassBgInput      = const Color(0x0DFFFFFF);
  static Color glassBgHover      = const Color(0x1FFFFFFF);
  static Color glassBorder       = const Color(0x2EFFFFFF);
  static Color glassBorderStrong = const Color(0x4DFFFFFF);

  // Navigation
  static Color navActive     = const Color(0xFFEF4444);
  static Color navActiveGlow = const Color(0x55EF4444);
  static Color navInactive   = const Color(0x99FFFFFF);

  // Text on dark glass
  static Color textPrimary   = const Color(0xFFF1F5F9);
  static Color textSecondary = const Color(0xB3FFFFFF);
  static Color textMuted     = const Color(0x66FFFFFF);

  // Semantic
  static Color primaryBlue   = const Color(0xFF3B82F6);
  static Color primaryGlow   = const Color(0x553B82F6);
  static Color accentBlue    = const Color(0xFF60A5FA);
  static Color successGreen  = const Color(0xFF10B981);
  static Color successGlow   = const Color(0x3310B981);
  static Color warningOrange = const Color(0xFFF59E0B);
  static Color errorRed      = const Color(0xFFEF4444);
  static Color errorGlow     = const Color(0x33EF4444);
  static Color bloodType     = const Color(0xFFF87171);
  static Color allergyColor  = const Color(0xFFFB923C);
  // Marks paper stocks taken from the vendor's "Black Bar position" spec
  // sheets in the paper picker — deliberately outside the blue/green/orange
  // set those rows already use for the B/F/– suffix dot.
  static Color accentViolet  = const Color(0xFFA78BFA);

  // Legacy aliases
  static Color borderColor  = const Color(0x2EFFFFFF);
  static Color contentBg    = const Color(0x0AFFFFFF);
  static Color lightBlue    = const Color(0x152563EB);
  static Color successLight = const Color(0x1510B981);
  static Color errorLight   = const Color(0x15EF4444);
  static Color warningLight = const Color(0x15F59E0B);
  static Color cardBg       = const Color(0x10FFFFFF);
  static Color textPrimary2 = const Color(0xFFF1F5F9);

  // ── Theme flag ───────────────────────────────────────────────────────────
  static bool isDark = true;

  // ── Apply dark palette ───────────────────────────────────────────────────
  static void applyDark() {
    isDark = true;
    bg1 = const Color(0xFF080D1E);
    bg2 = const Color(0xFF0D1840);
    bg3 = const Color(0xFF120A34);
    orb1 = const Color(0x352563EB);
    orb2 = const Color(0x287C3AED);
    orb3 = const Color(0x1A0EA5E9);
    glassBg           = const Color(0x14FFFFFF);
    glassBgCard       = const Color(0x10FFFFFF);
    glassBgInput      = const Color(0x0DFFFFFF);
    glassBgHover      = const Color(0x1FFFFFFF);
    glassBorder       = const Color(0x2EFFFFFF);
    glassBorderStrong = const Color(0x4DFFFFFF);
    navActive         = const Color(0xFFEF4444);
    navActiveGlow     = const Color(0x55EF4444);
    navInactive       = const Color(0x99FFFFFF);
    textPrimary       = const Color(0xFFF1F5F9);
    textSecondary     = const Color(0xB3FFFFFF);
    textMuted         = const Color(0x66FFFFFF);
    primaryBlue       = const Color(0xFF3B82F6);
    primaryGlow       = const Color(0x553B82F6);
    accentBlue        = const Color(0xFF60A5FA);
    successGreen      = const Color(0xFF10B981);
    successGlow       = const Color(0x3310B981);
    warningOrange     = const Color(0xFFF59E0B);
    errorRed          = const Color(0xFFEF4444);
    errorGlow         = const Color(0x33EF4444);
    bloodType         = const Color(0xFFF87171);
    allergyColor      = const Color(0xFFFB923C);
    accentViolet      = const Color(0xFFA78BFA);  // violet-400, reads on dark
    borderColor       = const Color(0x2EFFFFFF);
    contentBg         = const Color(0x0AFFFFFF);
    lightBlue         = const Color(0x152563EB);
    successLight      = const Color(0x1510B981);
    errorLight        = const Color(0x15EF4444);
    warningLight      = const Color(0x15F59E0B);
    cardBg            = const Color(0x10FFFFFF);
    textPrimary2      = const Color(0xFFF1F5F9);
  }

  // ── Apply light palette ──────────────────────────────────────────────────
  static void applyLight() {
    // "Emerald Seashell Noon" — seashell/mint light canvas, black text, emerald accents.
    // Emerald #00A878 · Seashell #F0EDEA · Navy #1A5276 · Mint #A8D5B5
    isDark = false;
    bg1 = const Color(0xFFF0EDEA);  // seashell
    bg2 = const Color(0xFFE4F2EC);  // light mint
    bg3 = const Color(0xFFECF5F0);  // mint-seashell blend
    orb1 = const Color(0x7000A878); // emerald orb
    orb2 = const Color(0x60A8D5B5); // mint orb
    orb3 = const Color(0x401A5276); // navy orb
    // White-frosted glass panels on light seashell canvas
    glassBg           = const Color(0xAAFFFFFF);
    glassBgCard       = const Color(0x99FFFFFF);
    glassBgInput      = const Color(0xBBFFFFFF);
    glassBgHover      = const Color(0xCCFFFFFF);
    glassBorder       = const Color(0x3500A878);  // emerald border tint
    glassBorderStrong = const Color(0x5500A878);
    // Emerald accent
    navActive         = const Color(0xFF00A878);
    navActiveGlow     = const Color(0x4000A878);
    navInactive       = const Color(0xAA1A2332);  // dark gray for inactive nav
    // BLACK text on light background
    textPrimary       = const Color(0xFF1A2332);  // near-black
    textSecondary     = const Color(0xFF2C4A65);  // dark navy
    textMuted         = const Color(0xFF708090);  // slate
    primaryBlue       = const Color(0xFF00A878);  // emerald as primary
    primaryGlow       = const Color(0x5500A878);
    accentBlue        = const Color(0xFF1A5276);  // navy as accent
    successGreen      = const Color(0xFF00A878);
    successGlow       = const Color(0x4400A878);
    warningOrange     = const Color(0xFFD97706);
    errorRed          = const Color(0xFFDC2626);
    errorGlow         = const Color(0x44DC2626);
    bloodType         = const Color(0xFFDC2626);
    allergyColor      = const Color(0xFFEA580C);
    accentViolet      = const Color(0xFF7C3AED);  // violet-600, reads on seashell
    borderColor       = const Color(0x3500A878);
    contentBg         = const Color(0x22FFFFFF);
    lightBlue         = const Color(0x2000A878);
    successLight      = const Color(0x2000A878);
    errorLight        = const Color(0x20DC2626);
    warningLight      = const Color(0x20D97706);
    cardBg            = const Color(0x99FFFFFF);
    textPrimary2      = const Color(0xFF1A2332);
  }
}

// ─── Theme ───────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get theme => AppColors.isDark ? darkTheme : lightTheme;

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: AppColors.accentBlue,
        onSecondary: Colors.white,
        error: AppColors.errorRed,
        onError: Colors.white,
        surface: isDark ? const Color(0xFF0D1840) : const Color(0xFFF8FAFF),
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.glassBgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassBgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.8), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.glassBgHover,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.glassBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textTheme: TextTheme(
        displayMedium:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
        headlineLarge:  TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineSmall:  TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        titleSmall:     TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        bodyLarge:      TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
        bodyMedium:     TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        bodySmall:      TextStyle(fontSize: 12, color: AppColors.textMuted),
        labelLarge:     TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelSmall:     TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5),
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
      dividerTheme: DividerThemeData(color: AppColors.glassBorder, thickness: 1, space: 0),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primaryBlue : Colors.transparent),
        side: BorderSide(color: AppColors.glassBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
