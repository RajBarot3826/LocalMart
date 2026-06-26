import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFFFBF5DD);
  static const Color card = Color(0xFFE7E1B1);
  static const Color primary = Color(0xFF306D29);
  static const Color dark = Color(0xFF0D530E);

  static ThemeData theme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.poppinsTextTheme(),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
    ),
  );
}
