// lib/core/widgets/progress_bar.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 0-100%, รองรับ indeterminate (loading ไม่รู้ค่า %)
class AppProgressBar extends StatelessWidget {
  final double? percent; // null = indeterminate
  final bool showLabel;
  final Color? color;

  const AppProgressBar({super.key, required this.percent, this.showLabel = true, this.color});

  @override
  Widget build(BuildContext context) {
    final value = percent == null ? null : (percent!.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: AppColors.gray200,
            color: color ?? (percent != null && percent! >= 100 ? AppColors.success : AppColors.primary),
          ),
        ),
        if (showLabel && percent != null) ...[
          const SizedBox(height: 4),
          Text('${percent!.toStringAsFixed(0)}%', style: AppTextStyles.caption),
        ],
      ],
    );
  }
}