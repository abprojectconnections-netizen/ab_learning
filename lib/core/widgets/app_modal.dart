// lib/core/widgets/app_modal.dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// Modal/Dialog มาตรฐาน — เรียกผ่าน static method เพื่อความสม่ำเสมอทั้งแอป
class AppModal {
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'ยืนยัน',
    String cancelLabel = 'ยกเลิก',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppTextStyles.h3),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actionsPadding: const EdgeInsets.all(AppSpacing.md),
        actions: [
          AppButton(variant: AppButtonVariant.ghost, label: cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
          AppButton(
            variant: isDanger ? AppButtonVariant.danger : AppButtonVariant.primary,
            label: confirmLabel,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  static Future<T?> custom<T>(BuildContext context, {required Widget child, String? title}) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: title != null ? Text(title, style: AppTextStyles.h3) : null,
        content: child,
      ),
    );
  }
}