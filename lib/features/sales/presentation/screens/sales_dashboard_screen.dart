// lib/features/sales/presentation/screens/sales_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../revenue/presentation/providers/payout_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/theme/app_spacing.dart';

class SalesDashboardScreen extends ConsumerWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ยอดขาย')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => AppErrorState(message: 'โหลดยอดขายไม่สำเร็จ', onRetry: () => ref.invalidate(salesRecordsProvider)),
          data: (records) {
            return AppDataTable(
              items: records,
              emptyMessage: 'ยังไม่มีการขายในช่วงเวลานี้',
              columns: const [
                DataColumn(label: Text('วันที่')),
                DataColumn(label: Text('คอร์ส')),
                DataColumn(label: Text('ผู้ซื้อ')),
                DataColumn(label: Text('จำนวนเงิน')),
                DataColumn(label: Text('สถานะ')),
              ],
              rowBuilder: (r) => DataRow(cells: [
                DataCell(Text('${r.date.day}/${r.date.month}/${r.date.year}')),
                DataCell(Text(r.courseTitle)),
                DataCell(Text(r.buyerName)),
                DataCell(Text('฿${r.amount.toStringAsFixed(0)}')),
                const DataCell(StatusBadge(kind: StatusKind.paid)),
              ]),
            );
          },
        ),
      ),
    );
  }
}