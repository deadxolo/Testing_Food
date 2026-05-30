import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide colours & theme. Tuned for a glassmorphic look: the Scaffold is
/// transparent, every `Card` is a frosted-white pane, the AppBar and the
/// bottom NavigationBar blend into the gradient backdrop.
class AppColors {
  static const seed = Color(0xFF1B8A3A);
  static const bg = Color(0xFFF6F7F4);
  static const card = Colors.white;
  static const ink = Color(0xFF1A1F1A);
  static const inkSoft = Color(0xFF5A625A);

  // verdict / score bands
  static const good = Color(0xFF1B8A3A);
  static const okay = Color(0xFF7CB342);
  static const watch = Color(0xFFF6A609);
  static const poor = Color(0xFFEF6C00);
  static const bad = Color(0xFFD32F2F);

  static Color forPercent(int pct) {
    if (pct >= 80) return good;
    if (pct >= 62) return okay;
    if (pct >= 45) return watch;
    if (pct >= 25) return poor;
    return bad;
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.seed,
    scaffoldBackgroundColor: Colors.transparent, // gradient backdrop shows through
    brightness: Brightness.light,
  );

  // Reusable "frosted white" surface used by the Card theme.
  final glassFill = Colors.white.withValues(alpha: 0.62);
  final glassStroke = Colors.white.withValues(alpha: 0.55);

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineSmall: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: AppColors.ink),
      titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600, color: AppColors.ink),
      titleMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w600, color: AppColors.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      color: glassFill,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: glassStroke, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.70),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.seed.withValues(alpha: 0.18),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.seed : AppColors.inkSoft,
          fontSize: 11.5,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 1),
        backgroundColor: Colors.white.withValues(alpha: 0.45),
        foregroundColor: AppColors.ink,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
      backgroundColor: Colors.white.withValues(alpha: 0.65),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
