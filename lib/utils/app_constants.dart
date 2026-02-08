import 'package:flutter/material.dart';

class AppColors {
  // --- Sneat Primary Palette ---
  static const Color primary = Color(0xFF696CFF);
  static const Color primaryLight = Color(0xFFE7E7FF);

  // --- Secondary & Neutrals ---
  static const Color secondary = Color(0xFF8592A3);
  static const Color secondaryLight = Color(0xFFEBEEF0);

  // --- Semantic Colors (API Error/Success Handling) ---
  static const Color success = Color(0xFF71DD37);
  static const Color danger = Color(0xFFFF3E1D);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF03C3EC);

  // --- Background & Surface ---
  static const Color background = Color(0xFFF5F5F9);
  static const Color cardBackground = Colors.white;
  static const Color white = Color(0xFFFFFFFF);

  // --- Text Colors ---
  static const Color textDark = Color(0xFF566A7F);
  static const Color textMuted = Color(0xFFA1ACB8);
  static const Color textHeading = Color(0xFF566A7F);

  // --- Border & Dividers ---
  static const Color borderColor = Color(0xFFD9DEE3);
}

class AppDimensions {
  static const double borderRadius = 8.0;
  static const double cardPadding = 20.0;
  static const double inputPadding = 16.0;
}

class AppTypography {
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textHeading,
    fontFamily: 'PublicSans', // Sneat uses Public Sans
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: AppColors.textDark,
    fontFamily: 'PublicSans',
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    fontFamily: 'PublicSans',
  );
}
