// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    // ใช้ Noto Sans Thai เป็น base ทั้งหมดก่อน แล้วค่อย override จุดที่กำหนด token เฉพาะ
    final thaiTextTheme = GoogleFonts.notoSansThaiTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansThai(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      textTheme: thaiTextTheme.copyWith(
        headlineMedium: AppTextStyles.h1,
        headlineSmall: AppTextStyles.h2,
        titleMedium: AppTextStyles.h3,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gray300,
          disabledForegroundColor: AppColors.gray500,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
          textStyle: GoogleFonts.notoSansThai(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.notoSansThai(fontWeight: FontWeight.w500),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        labelStyle: GoogleFonts.notoSansThai(color: AppColors.gray600),
        hintStyle: GoogleFonts.notoSansThai(color: AppColors.gray400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          borderSide: const BorderSide(color: AppColors.gray200),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        margin: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.gray100,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.notoSansThai(color: AppColors.gray800, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.gray200,
      ),

      dividerTheme: const DividerThemeData(color: AppColors.gray200, thickness: 1),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.gray900,
        contentTextStyle: GoogleFonts.notoSansThai(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      ),
    );
  }
}