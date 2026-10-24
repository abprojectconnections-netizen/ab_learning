// lib/core/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum StatusKind { draft, published, pending, paid, failed, refunded }

class StatusBadge extends StatelessWidget {
  final StatusKind kind;
  const StatusBadge({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (kind) {
      StatusKind.draft => (AppColors.statusDraft, 'ฉบับร่าง'),
      StatusKind.published => (AppColors.statusPublished, 'เผยแพร่แล้ว'),
      StatusKind.pending => (AppColors.statusPending, 'รอดำเนินการ'),
      StatusKind.paid => (AppColors.statusPaid, 'ชำระแล้ว'),
      StatusKind.failed => (AppColors.statusFailed, 'ล้มเหลว'),
      StatusKind.refunded => (AppColors.statusRefunded, 'คืนเงินแล้ว'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}