import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dusk-sky palette: the app lives in the hour after sunset.
class C {
  static const night = Color(0xFF0D0A1E);
  static const dusk = Color(0xFF281A55);
  static const coral = Color(0xFFFF6F59);
  static const amber = Color(0xFFFFC857);
  static const lagoon = Color(0xFF3FD0C9);
  static const ink = Color(0xFF1A1030);

  static const sunset = LinearGradient(
    colors: [coral, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Fraunces: warm, characterful serif for headings and ticket titles.
TextStyle display(double size, {FontWeight w = FontWeight.w600, Color? color}) =>
    GoogleFonts.fraunces(fontSize: size, fontWeight: w, color: color ?? Colors.white, height: 1.15);

/// DM Sans: clean, friendly body text.
TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? color, double h = 1.45}) =>
    GoogleFonts.dmSans(fontSize: size, fontWeight: w, color: color ?? Colors.white, height: h);

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: C.night,
      colorScheme: const ColorScheme.dark(primary: C.coral, secondary: C.amber, surface: C.night),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
    );
