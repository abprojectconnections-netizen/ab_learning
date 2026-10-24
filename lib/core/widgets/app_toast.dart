// lib/core/widgets/app_toast.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppToastType { success, error, info }

class AppToast {
  static void show(BuildContext context, String message, {AppToastType type = AppToastType.info}) {
    final (icon, color) = switch (type) {
      AppToastType.success => (Icons.check_circle, AppColors.success),
      AppToastType.error => (Icons.error, AppColors.danger),
      AppToastType.info => (Icons.info, AppColors.primary),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}