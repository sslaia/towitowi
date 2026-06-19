import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Primary Theme Colors (Extracted from TowiTowi specs)
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color onBackground = Color(0xFFE2E2E2);
  static const Color onSurface = Color(0xFFE2E2E2);

  static const Color primary = Color(0xFFFFF6DF);
  static const Color onPrimary = Color(0xFF3A3000);

  static const Color primaryContainer = Color(0xFFFFD700); // Gold Accent
  static const Color onPrimaryContainer = Color(0xFF705E00);

  static const Color secondary = Color(0xFFFFB4A8);
  static const Color onSecondary = Color(0xFF690000);

  static const Color secondaryContainer = Color(
    0xFF920703,
  ); // Oxblood Red Accent
  static const Color onSecondaryContainer = Color(0xFFFF9A8A);

  static const Color tertiary = Color(0xFFF9F5F5);
  static const Color onTertiary = Color(0xFF313030);

  static const Color outline = Color(0xFF999077);
  static const Color outlineVariant = Color(0xFF4D4732);

  static const Color surfaceBright = Color(0xFF393939);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1F1F1F);
  static const Color surfaceContainerLow = Color(0xFF1B1B1B);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353535);

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(
        0xFF000000,
      ), // Inky black as per brand guidelines
      colorScheme: const ColorScheme.dark(
        surface: surface,
        onSurface: onSurface,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        outline: outline,
        outlineVariant: outlineVariant,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
      ),
      textTheme: TextTheme(
        // display-lg (EB Garamond)
        displayLarge: GoogleFonts.ebGaramond(
          fontSize: 48,
          fontWeight: FontWeight.w500,
          height: 56 / 48,
          letterSpacing: -0.02 * 48,
          color: primary,
        ),
        // headline-lg (EB Garamond)
        headlineLarge: GoogleFonts.ebGaramond(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          height: 40 / 32,
          color: onSurface,
        ),
        // headline-md (EB Garamond)
        headlineMedium: GoogleFonts.ebGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 32 / 24,
          color: onSurface,
        ),
        // body-lg (Hanken Grotesk)
        bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 28 / 18,
          color: onSurface,
        ),
        // body-md (Hanken Grotesk)
        bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: onSurface,
        ),
        // label-md (Hanken Grotesk)
        labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
          letterSpacing: 0.05 * 14,
          color: primaryContainer, // Accent gold for active labels
        ),
        // caption (Hanken Grotesk)
        bodySmall: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 16 / 12,
          color: onSurface.withValues(alpha: 0.6),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
