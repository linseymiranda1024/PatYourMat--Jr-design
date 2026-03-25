import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand palette
  static const Color primaryPurple = Color(0xFF8A2BFF);
  static const Color secondaryBlue = Color(0xFF2F7BFF);
  static const Color accentPurple = Color(0xFF5E54FF);
  static const Color darkPurple = accentPurple;
  static const Color deepPurple = secondaryBlue;

  // Shared gradients
  static const Color gradientStart = primaryPurple;
  static const Color gradientEnd = secondaryBlue;
  static const Color gradientStartDark = Color(0xFF2B2337);
  static const Color gradientEndDark = Color(0xFF202A39);

  // Neutral surfaces
  static const Color surfaceLight = Color(0xFFF6F4FC);
  static const Color surfaceContainerLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A1A1F);
  static const Color surfaceDimDark = Color(0xFF15151A);
  static const Color surfaceBrightDark = Color(0xFF32323A);
  static const Color surfaceContainerLowestDark = Color(0xFF141419);
  static const Color surfaceContainerLowDark = Color(0xFF1D1D24);
  static const Color surfaceContainerDark = Color(0xFF25252C);
  static const Color surfaceContainerHighDark = Color(0xFF2A2A32);
  static const Color surfaceContainerHighestDark = Color(0xFF30303A);
  static const Color outlineLight = Color(0xFFD7D0E6);
  static const Color outlineDark = Color(0xFF4D475B);
  static const Color outlineVariantDark = Color(0xFF3C3648);
  static const Color outlineVariantLight = Color(0xFFE3DCEC);

  // Text
  static const Color onSurfaceLight = Color(0xFF211C2B);
  static const Color onSurfaceLightMuted = Color(0xFF625B71);
  static const Color onSurfaceDark = Color(0xFFF3EEF9);
  static const Color onSurfaceDarkMuted = Color(0xFFC9C2D9);

  // Semantic statuses migrated from the legacy palette
  static const Color success = Color(0xFF28824C);
  static const Color warning = Color(0xFF7E8228);
  static const Color error = Color(0xFF822828);
  static const Color info = Color(0xFF3F5C74);

  // Legacy aliases retained for incremental migration
  static const Color cloudGrey = Color(0xFFF1F0EB);
  static const Color offWhite = Color(0xFFF7F7F7);

  // Settings and form treatments
  static const Color fieldFillLight = Color(0xFFFFFFFF);
  static const Color fieldFillDark = Color(0xFF2A2931);
  static const Color fieldFill = Color.fromRGBO(255, 255, 255, 0.15);
  static const Color headerOnBrand = Color(0xFFF8F4FF);
  static const Color headerOnBrandMuted = Color(0xFFDCCFF6);

  // Legacy text aliases retained for screens still using the older API.
  static const Color textLight = headerOnBrand;
  static const Color textLight70 = Color(0xB3F8F4FF);
  static const Color textLight60 = Color(0x99F8F4FF);
}
