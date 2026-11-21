import 'package:flutter/material.dart';

const Color kBg = Color(0xFF070A1F);
const Color kCard = Color(0xFF0D1236);
const Color kLine = Color(0xFF2A3CA8);
const Color kCyan = Color(0xFF2FE4FF);
const Color kMint = Color(0xFF7FD6B8);
const Color kMuted = Color(0xFF8F9BD6);

ThemeData buildAlexTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(primary: kCyan, surface: kCard),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
