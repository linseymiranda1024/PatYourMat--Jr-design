// -----------------------------------------------------------------------
// Filename: theme.dart
// Original Author: Emily Ehrenberg
// Updated By: Codex
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains the themes for the app.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////

// Flutter external package imports
import 'package:flutter/material.dart';

import 'app_colors.dart';

//////////////////////////////////////////////////////////////////////////
// LIGHT-MODE THEME
//////////////////////////////////////////////////////////////////////////
final ThemeData lightTheme = _buildTheme(Brightness.light);

//////////////////////////////////////////////////////////////////////////
// DARK-MODE THEME
//////////////////////////////////////////////////////////////////////////
final ThemeData darkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final seedScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryPurple,
    brightness: brightness,
  );

  final colorScheme = seedScheme.copyWith(
    primary: AppColors.primaryPurple,
    secondary: AppColors.secondaryBlue,
    tertiary: AppColors.accentPurple,
    surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    surfaceDim: isDark ? AppColors.surfaceDimDark : const Color(0xFFE7E1F0),
    surfaceBright: isDark
        ? AppColors.surfaceBrightDark
        : const Color(0xFFFDF8FF),
    surfaceContainerLowest: isDark
        ? AppColors.surfaceContainerLowestDark
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: isDark
        ? AppColors.surfaceContainerLowDark
        : const Color(0xFFF8F4FC),
    surfaceContainer: isDark
        ? AppColors.surfaceContainerDark
        : AppColors.surfaceContainerLight,
    surfaceContainerHigh: isDark
        ? AppColors.surfaceContainerHighDark
        : const Color(0xFFF1ECF8),
    surfaceContainerHighest: isDark
        ? AppColors.surfaceContainerHighestDark
        : const Color(0xFFEAE3F3),
    onSurface: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
    onSurfaceVariant: isDark
        ? AppColors.onSurfaceDarkMuted
        : AppColors.onSurfaceLightMuted,
    outline: isDark ? AppColors.outlineDark : AppColors.outlineLight,
    outlineVariant: isDark
        ? AppColors.outlineVariantDark
        : AppColors.outlineVariantLight,
    error: AppColors.error,
    onError: AppColors.headerOnBrand,
  );

  final baseTextTheme = isDark
      ? Typography.whiteRedmond
      : Typography.blackRedmond;
  final textTheme = baseTextTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  final theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: colorScheme.outline),
  );

  return theme.copyWith(
    canvasColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: IconThemeData(color: colorScheme.primary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.fieldFillDark : AppColors.fieldFillLight,
      constraints: const BoxConstraints(minHeight: 70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      iconColor: colorScheme.primary,
      prefixIconColor: colorScheme.primary,
      suffixIconColor: colorScheme.primary,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.primary.withValues(alpha: 0.38);
          }
          return colorScheme.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onPrimary.withValues(alpha: 0.78);
          }
          return colorScheme.onPrimary;
        }),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimary,
              ) ??
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimary,
              ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700) ??
              const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      selectedLabelStyle: textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: textTheme.labelSmall,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: isDark ? 0.32 : 0.5),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark
          ? AppColors.surfaceContainerDark
          : colorScheme.onSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDark ? AppColors.onSurfaceDark : AppColors.headerOnBrand,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
