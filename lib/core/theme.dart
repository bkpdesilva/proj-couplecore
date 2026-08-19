import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF8B7FD8);
  static const primaryDark = Color(0xFF6B5FD8);
  static const background = Color(0xFFF8F9FE);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
      );
}
