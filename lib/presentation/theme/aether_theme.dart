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

  // ── Color Palette (Spotify Inspired) ──────────────────────────────────────

  // Primary backgrounds
  static const Color bg         = Color(0xFF121212); // Spotify near-black
  static const Color bgSurface  = Color(0xFF181818); // Spotify dark surface
  static const Color bgCard     = Color(0xFF181818); // Spotify card surface
  static const Color bgElevated = Color(0xFF1F1F1F); // Spotify mid-dark interactive
  static const Color cardHover  = Color(0xFF252525); // Elevated card

  // Accent (Spotify Green)
  static const Color teal       = Color(0xFF1ED760); // Iconic Spotify Green
  static const Color spotifyGreen = Color(0xFF1ED760);
  static const Color tealDim    = Color(0xFF1DB954); // Green border / dim
  static const Color tealFaint  = Color(0xFF163824); // Faint green bg

  // SOS / Semantic
  static const Color sosRed     = Color(0xFFF3727F); // Spotify negative red
  static const Color sosRedDim  = Color(0xFFB03842);
  static const Color sosSurface = Color(0xFF281416);
  static const Color warningOrange = Color(0xFFFFA42B); // Spotify warning orange
  static const Color infoBlue   = Color(0xFF539DF5); // Spotify announcement blue

  // Status colors
  static const Color statusGreen  = Color(0xFF1ED760);
  static const Color statusYellow = Color(0xFFFFA42B);
  static const Color statusRed    = Color(0xFFF3727F);
  static const Color statusGray   = Color(0xFFB3B3B3);

  // Text (Spotify Hierarchy)
  static const Color textPrimary   = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFFB3B3B3); // Spotify silver
  static const Color textTertiary  = Color(0xFF7C7C7C); // Muted silver
  static const Color textTeal      = teal;

  // Borders & Separators
  static const Color border      = Color(0xFF282828); // Subtle dark border
  static const Color borderTeal  = Color(0xFF1DB954); // Green accent border
  static const Color borderLight = Color(0xFF4D4D4D); // Mid gray border

  // Message bubbles
  static const Color bubbleOut   = Color(0xFF163824); // Outgoing (Spotify green-black tint)
  static const Color bubbleIn    = Color(0xFF252525); // Incoming (dark card)

  // ── Heavy Shadows (Spotify Elevation) ──────────────────────────────────────
  static const List<BoxShadow> shadowHeavy = [
    BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 8)),
  ];

  // ── Typography ─────────────────────────────────────────────────────────────

  static TextTheme get _textTheme {
    try {
      return GoogleFonts.interTextTheme(_baseTextTheme);
    } catch (_) {
      return _baseTextTheme;
    }
  }

  static const TextTheme _baseTextTheme = TextTheme(
    displayLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: textPrimary),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: textPrimary),
    displaySmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: textPrimary),
    headlineLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0, color: textPrimary),
    headlineMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
    headlineSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0, color: textPrimary),
    titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0, color: textPrimary),
    titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: textPrimary),
    titleSmall:    TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: textSecondary),
    bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0, color: textPrimary),
    bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, color: textPrimary),
    bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0, color: textSecondary),
    labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: textPrimary),
    labelMedium:   TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: textSecondary),
    labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: textTertiary),
  );

  // ── Theme Data ─────────────────────────────────────────────────────────────

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: teal,
        onPrimary: Color(0xFF000000),
        secondary: tealDim,
        onSecondary: Color(0xFF000000),
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
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: tealFaint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w700);
          }
          return const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500);
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
          borderRadius: BorderRadius.circular(8), // Spotify 8px radius
          side: const BorderSide(color: border, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999), // Spotify full pill search/input
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: sosRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: const Color(0xFF000000),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)), // Spotify pill button
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: textTertiary, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)), // Spotify outlined pill
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
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
