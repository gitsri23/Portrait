import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CinematicTheme {
  static const Color pureBlack = Color(0xFF000000);
  static const Color softWhite = Color(0xFFF5F5F7);
  static const Color subtleCyan = Color(0xFFE0F7FA);

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: pureBlack,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: softWhite,
          displayColor: softWhite,
        ),
        iconTheme: const IconThemeData(
          color: softWhite,
          size: 28,
        ),
      );
}
