// lib/features/revenue/presentation/screens/payout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payout_providers.dart';
import '../../domain/payout_model.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/theme/app_spacing.dart';

class PayoutHistoryScreen extends ConsumerWidget {
  const PayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(payoutHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการถอนเงิน')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(message: 'โหลดประวัติไม่สำเร็จ', onRetry: () => ref.invalidate(payoutHistoryProvider)),
        data: (history) {
          if (history.isEmpty) return const AppEmptyState(message: 'ยังไม่มีประวัติการถอนเงิน');
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: history.length,
            itemBuilder: (c, i) {
              final p = history[i];
              final statusKind = switch (p.status) {
                PayoutStatus.pending => StatusKind.pending,
                PayoutStatus.approved => StatusKind.published,
                PayoutStatus.paid => StatusKind.paid,
                PayoutStatus.rejected => StatusKind.failed,
              };
              return Card(
                child: ListTile(
                  title: Text('฿${p.amount.toStringAsFixed(0)}'),
                  subtitle: Text('วันที่ขอ: ${p.requestedAt.day}/${p.requestedAt.month}/${p.requestedAt.year}'),
                  trailing: StatusBadge(kind: statusKind),
                ),
              );
            },
          );
        },
      ),
    );
  }
}