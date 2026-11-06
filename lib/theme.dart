import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color paper = Color(0xFFF6EBD3);
  static const Color card = Color(0xFFFFFBF0);
  static const Color ink = Color(0xFF2B1D14);
  static const Color inkSoft = Color(0xFF6B5846);
  static const Color red = Color(0xFF8E1B16);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldDark = Color(0xFF8A6D12);
  static const Color green = Color(0xFF2E7D32);
  static const Color wrong = Color(0xFFB3261E);
  static const Color rightBg = Color(0xFFDCEFD9);
  static const Color wrongBg = Color(0xFFF8D7D3);
}

const String kSerif = 'serif';

/// Kiểu chữ có chân (giọng văn khoa cử) dùng cho tiêu đề và lời thoại.
TextStyle serif({
  double size = 16,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.ink,
  double? height,
  double? letterSpacing,
  FontStyle? style,
}) {
  return TextStyle(
    fontFamily: kSerif,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: style,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.paper,
  );
}
