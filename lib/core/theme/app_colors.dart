// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Design Tokens — สี (อ้างอิงจาก Phase 2: UX/UI Design Foundations)
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2E5AFF);
  static const Color secondary = Color(0xFF00C48C);

  // Semantic
  static const Color danger = Color(0xFFFF4D4F);
  static const Color warning = Color(0xFFFFA940);
  static const Color success = Color(0xFF00C48C);
  static const Color info = Color(0xFF2E5AFF);

  // Neutral Grays (9 steps: 50 สว่างสุด -> 900 เข้มสุด)
  static const Color gray50 = Color(0xFFF8FAFC);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray900 = Color(0xFF0F172A);

  // Background / Surface
  static const Color background = gray50;
  static const Color surface = Colors.white;

  // Status Badge colors (ตาม State ที่กำหนดใน Design System)
  static const Color statusDraft = gray400;
  static const Color statusPublished = success;
  static const Color statusPending = warning;
  static const Color statusPaid = success;
  static const Color statusFailed = danger;
  static const Color statusRefunded = gray500;
}