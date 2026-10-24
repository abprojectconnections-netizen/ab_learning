// lib/core/widgets/certificate_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'progress_bar.dart';
import 'app_button.dart';

enum CertificateCardState { locked, ready, downloaded }

class CertificateCard extends StatelessWidget {
  final String courseTitle;
  final String? learnerName;
  final DateTime? issuedAt;
  final String? verificationCode;
  final CertificateCardState state;
  final double? progressPercent; // ใช้เมื่อ state = locked
  final VoidCallback? onDownload;

  const CertificateCard({
    super.key,
    required this.courseTitle,
    this.learnerName,
    this.issuedAt,
    this.verificationCode,
    required this.state,
    this.progressPercent,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = state == CertificateCardState.locked;
    return Card(
      color: isLocked ? AppColors.gray100 : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium,
                  size: 36,
                  color: isLocked ? AppColors.gray400 : Colors.amber,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(courseTitle, style: AppTextStyles.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isLocked) ...[
              AppProgressBar(percent: progressPercent ?? 0, showLabel: false),
              const SizedBox(height: AppSpacing.sm),
              Text('เรียนอีก ${(100 - (progressPercent ?? 0)).toStringAsFixed(0)}% เพื่อรับใบนี้', style: AppTextStyles.caption),
            ] else ...[
              if (learnerName != null) Text('ออกให้: $learnerName', style: AppTextStyles.bodyMedium),
              if (issuedAt != null) Text('วันที่: ${issuedAt!.day}/${issuedAt!.month}/${issuedAt!.year}', style: AppTextStyles.caption),
              if (verificationCode != null) Text('รหัส: $verificationCode', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: state == CertificateCardState.downloaded ? 'ดาวน์โหลดอีกครั้ง' : 'ดาวน์โหลด PDF',
                icon: Icons.download,
                variant: AppButtonVariant.secondary,
                onPressed: onDownload,
              ),
            ],
          ],
        ),
      ),
    );
  }
}