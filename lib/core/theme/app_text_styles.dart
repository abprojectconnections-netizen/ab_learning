// lib/core/theme/app_text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Design Tokens — Typography (Font Scale: 12/14/16/20/24/32px ตาม Phase 2)
/// ใช้ Noto Sans Thai เป็นฟอนต์หลัก รองรับภาษาไทย+อังกฤษผสมตามที่กำหนดไว้
class AppTextStyles {
  AppTextStyles._();

  static TextStyle h1 = GoogleFonts.notoSansThai(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.gray900,
    height: 1.3,
  );

  static TextStyle h2 = GoogleFonts.notoSansThai(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.gray900,
    height: 1.3,
  );

  static TextStyle h3 = GoogleFonts.notoSansThai(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.gray900,
    height: 1.4,
  );

  static TextStyle bodyLarge = GoogleFonts.notoSansThai(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.gray800,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.notoSansThai(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.gray700,
    height: 1.5,
  );

  static TextStyle caption = GoogleFonts.notoSansThai(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.gray500,
    height: 1.4,
  );

  static TextStyle button = GoogleFonts.notoSansThai(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle link = GoogleFonts.notoSansThai(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
  );
}