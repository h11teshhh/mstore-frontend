import 'package:flutter/material.dart';

class AppColors {
  // --- Primary — softer indigo (was harsh #696CFF) ---
  static const Color primary        = Color(0xFF5F63F2);
  static const Color primaryLight   = Color(0xFFEEEEFD);
  static const Color primaryDark    = Color(0xFF4347D9);

  // --- Secondary & Neutrals ---
  static const Color secondary      = Color(0xFF8592A3);
  static const Color secondaryLight = Color(0xFFEBEEF0);

  // --- Semantic — softened, professional ---
  static const Color success        = Color(0xFF29C76F);   // deep green
  static const Color successLight   = Color(0xFFE8F8F0);
  static const Color danger         = Color(0xFFD93025);   // soft premium red
  static const Color dangerLight    = Color(0xFFFDECEB);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color warningLight   = Color(0xFFFFF8E6);
  static const Color info           = Color(0xFF00B4D8);
  static const Color infoLight      = Color(0xFFE0F7FD);

  // --- Due / Pending amounts — elegant red ---
  static const Color dueAmount      = Color(0xFFC0392B);   // muted deep red
  static const Color dueLight       = Color(0xFFFDF2F2);

  // --- Paid / Received amounts — premium dark ---
  static const Color paidAmount     = Color(0xFF1A1A2E);   // near-black premium
  static const Color paidLight      = Color(0xFFF0F0F5);

  // --- Background & Surface ---
  static const Color background     = Color(0xFFF4F5FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface        = Color(0xFFFAFAFF);
  static const Color white          = Color(0xFFFFFFFF);

  // --- Text ---
  static const Color textDark       = Color(0xFF4A5568);
  static const Color textMuted      = Color(0xFF9AA5B4);
  static const Color textHeading    = Color(0xFF2D3748);
  static const Color textLight      = Color(0xFFCBD5E0);

  // --- Border & Dividers ---
  static const Color borderColor    = Color(0xFFE2E8F0);
  static const Color divider        = Color(0xFFF0F2F5);
}

class AppDimensions {
  // Responsive helpers
  static double screenWidth(BuildContext ctx)  => MediaQuery.of(ctx).size.width;
  static double screenHeight(BuildContext ctx) => MediaQuery.of(ctx).size.height;
  static bool   isMobile(BuildContext ctx)     => screenWidth(ctx) < 600;
  static bool   isTablet(BuildContext ctx)     => screenWidth(ctx) >= 600 && screenWidth(ctx) < 1024;
  static bool   isDesktop(BuildContext ctx)    => screenWidth(ctx) >= 1024;

  static double horizontalPadding(BuildContext ctx) {
    if (isDesktop(ctx)) return screenWidth(ctx) * 0.12;
    if (isTablet(ctx))  return 32.0;
    return 16.0;
  }

  static double cardMaxWidth(BuildContext ctx) {
    if (isDesktop(ctx)) return 900;
    if (isTablet(ctx))  return 700;
    return double.infinity;
  }

  static const double borderRadius  = 10.0;
  static const double borderRadiusL = 16.0;
  static const double borderRadiusXL= 24.0;
  static const double cardPadding   = 20.0;
  static const double inputPadding  = 16.0;
  static const double spacing       = 16.0;
  static const double spacingS      = 8.0;
  static const double spacingL      = 24.0;
  static const double spacingXL     = 32.0;
}

class AppTypography {
  static const String _font = 'PublicSans';

  static const TextStyle heading = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textHeading, fontFamily: _font, letterSpacing: -0.3,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600,
    color: AppColors.textHeading, fontFamily: _font,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textDark, fontFamily: _font, height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    color: AppColors.textDark, fontFamily: _font,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: AppColors.textMuted, fontFamily: _font, letterSpacing: 0.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.textMuted, fontFamily: _font,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w700,
    color: AppColors.white, fontFamily: _font, letterSpacing: 0.8,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w800,
    color: AppColors.textHeading, fontFamily: _font,
  );
}

/// Reusable card shadow
List<BoxShadow> get cardShadow => [
  BoxShadow(
    color: const Color(0xFF5F63F2).withOpacity(0.06),
    blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: Colors.black.withOpacity(0.04),
    blurRadius: 4, offset: const Offset(0, 1),
  ),
];
