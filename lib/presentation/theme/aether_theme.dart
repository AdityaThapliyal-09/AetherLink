// AetherLink Design System
// Dark theme optimized for emergency/disaster scenarios:
// - High contrast for low-light readability
// - Dark blue background, teal accents, white text
// - Subtle surface textures via elevation + borders
// - Google Fonts: Inter (fallback to system font)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AetherTheme {
  AetherTheme._();

  // ── Color Palette ──────────────────────────────────────────────────────────

  // Primary backgrounds
  static const Color bg         = Color(0xFF0A1628); // Dark navy
  static const Color bgSurface  = Color(0xFF0F1E38); // Slightly lighter navy
  static const Color bgCard     = Color(0xFF132040); // Card background
  static const Color bgElevated = Color(0xFF172549); // Elevated card

  // Accent
  static const Color teal       = Color(0xFF00D4AA); // Primary teal accent
  static const Color tealDim    = Color(0xFF00A882); // Dimmed teal
  static const Color tealFaint  = Color(0xFF0D3830); // Very faint teal bg

  // SOS / Emergency
  static const Color sosRed     = Color(0xFFE53E3E);
  static const Color sosRedDim  = Color(0xFFB02828);
  static const Color sosSurface = Color(0xFF2D1212);

  // Status colors
  static const Color statusGreen  = Color(0xFF22C55E);
  static const Color statusYellow = Color(0xFFF59E0B);
  static const Color statusRed    = Color(0xFFEF4444);
  static const Color statusGray   = Color(0xFF94A3B8);

  // Text
  static const Color textPrimary   = Color(0xFFF0F6FF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary  = Color(0xFF4D6187);
  static const Color textTeal      = teal;

  // Borders
  static const Color border      = Color(0xFF1E3050);
  static const Color borderTeal  = Color(0xFF1A3C40);

  // Message bubbles
  static const Color bubbleOut   = Color(0xFF0D3B38); // Outgoing (teal tint)
  static const Color bubbleIn    = Color(0xFF132040); // Incoming (card)

  // ── Typography ─────────────────────────────────────────────────────────────

  static TextTheme get _textTheme {
    try {
      return GoogleFonts.interTextTheme(_baseTextTheme);
    } catch (_) {
      return _baseTextTheme;
    }
  }

  static const TextTheme _baseTextTheme = TextTheme(
    displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: textPrimary),
    displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: textPrimary),
    displaySmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: textPrimary),
    headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
    headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
    headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
    titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
    titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: textPrimary),
    titleSmall:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: textSecondary),
    bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0, color: textPrimary),
    bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, color: textPrimary),
    bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0, color: textSecondary),
    labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: textPrimary),
    labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: textSecondary),
    labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: textTertiary),
  );

  // ── Theme Data ─────────────────────────────────────────────────────────────

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: teal,
        onPrimary: bg,
        secondary: tealDim,
        onSecondary: bg,
        surface: bgSurface,
        onSurface: textPrimary,
        error: sosRed,
        onError: textPrimary,
        outline: border,
        surfaceContainerHighest: bgElevated,
      ),
      textTheme: _textTheme,
      primaryTextTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: _baseTextTheme.headlineMedium,
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgSurface,
        indicatorColor: tealFaint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: teal, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: teal, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        hintStyle: const TextStyle(color: textTertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: sosRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: teal,
          side: const BorderSide(color: teal),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgElevated,
        selectedColor: tealFaint,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? teal : textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? tealFaint : bgElevated;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: _baseTextTheme.headlineMedium,
        contentTextStyle: _baseTextTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgCard,
        modalBackgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

// ── Design Tokens (for direct use in widgets) ──────────────────────────────

class AetherSpacing {
  AetherSpacing._();
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

class AetherRadius {
  AetherRadius._();
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double full = 999;
}
