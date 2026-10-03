import 'package:flutter/material.dart';

class AppTheme {
  // Core Modern Light Palette (#D0F500 accent, #F8F9FA background, #FFFFFF cards)
  static const Color bg = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEEEEEE);
  static const Color subtleBorder = Color(0xFFF2F3F5);
  static const Color muted = Color(0xFF767676);
  static const Color primary = Color(0xFF1D1D1D);
  static const Color accent = Color(0xFFD0F500); // Lime / Chartreuse
  static const Color textPrimary = Color(0xFF1D1D1D);
  static const Color textSecondary = Color(0xFF767676);
  static const Color expenseRed = Color(0xFFFF5A5F);
  static const Color positiveGreen = Color(0xFF7ED321);
  static const Color inactiveGray = Color(0xFFE5E7EB);
  static const Color iconBg = Color(0xFFF4F5F7);

  // Backward-compatibility aliases for existing dark* names used across screens
  static const Color darkBg = bg;
  static const Color darkSurface = surface;
  static const Color darkCard = card;
  static const Color darkBorder = border;
  static const Color darkMuted = muted;
  static const Color darkPrimary = primary;
  static const Color darkAccent = accent;
  static const Color darkTextPrimary = textPrimary;
  static const Color darkTextSecondary = textSecondary;

  // Geometry / Radii
  static const double radiusHero = 24.0;
  static const double radiusCard = 22.0;
  static const double radiusTransaction = 16.0;
  static const double radiusButton = 16.0;
  static const double radiusInput = 14.0;
  static const double radiusChip = 12.0;

  // Soft lifted neumorphic / floating card shadows
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x0A000000), // ~4% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x04000000), // ~1.5% black
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get subtleShadow => const [
    BoxShadow(
      color: Color(0x07000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get heroLimeShadow => const [
    BoxShadow(
      color: Color(0x22B2D400),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // Common Reusable Card Decorations
  static BoxDecoration get heroLimeCardDecoration => BoxDecoration(
    color: accent,
    borderRadius: BorderRadius.circular(radiusHero),
    boxShadow: heroLimeShadow,
    border: Border.all(color: const Color(0xFFC4E800), width: 1),
  );

  static BoxDecoration get whiteCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusCard),
    boxShadow: cardShadow,
    border: Border.all(color: border, width: 1),
  );

  static BoxDecoration get transactionCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusTransaction),
    boxShadow: subtleShadow,
    border: Border.all(color: border, width: 1),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        surfaceContainerLowest: bg,
        surfaceContainerLow: bg,
        surfaceContainer: surface,
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border, width: 1),
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: textPrimary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: textPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}

