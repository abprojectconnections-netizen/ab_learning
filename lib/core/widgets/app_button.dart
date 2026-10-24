// lib/core/widgets/app_button.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

/// ปุ่มมาตรฐานของ Design System — รองรับ default/hover/pressed/disabled/loading
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final child = isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.ghost
                  ? AppColors.primary
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: fullWidth ? TextAlign.center : TextAlign.start,
                ),
              ),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary =>
        ElevatedButton(onPressed: disabled ? null : onPressed, child: child),
      AppButtonVariant.secondary =>
        OutlinedButton(onPressed: disabled ? null : onPressed, child: child),
      AppButtonVariant.danger => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.gray300,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          onPressed: disabled ? null : onPressed,
          child: child,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
