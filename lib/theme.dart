import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors taken from the Hoot logo: blue, lime green and dark navy.
class HootColors {
  static const blue = Color(0xFF2458BF);
  static const blueLight = Color(0xFF3D7BE8);
  static const green = Color(0xFF98C840);
  static const greenDark = Color(0xFF5E9A1E);
  static const navy = Color(0xFF0B2545);
  static const bg = Color(0xFFF3F6FB);
  static const line = Color(0xFFE6ECF5);
  static const muted = Color(0xFF7A879A);
  static const hot = Color(0xFFEF5B3B);
  static const danger = Color(0xFFD93A3A);

  static const brandGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [blue, blueLight],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1C47A8), blue, Color(0xFF2F74DA)],
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HootColors.blue,
      primary: HootColors.blue,
      secondary: HootColors.green,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: HootColors.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: HootColors.navy,
      displayColor: HootColors.navy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HootColors.bg,
      foregroundColor: HootColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: HootColors.green.withOpacity(0.25),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? HootColors.blue : HootColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? HootColors.blue : HootColors.muted,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HootColors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: HootColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: HootColors.blue, width: 1.6)),
    ),
  );
}
