// lib/features/revenue/presentation/screens/revenue_balance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/payout_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

const kMinPayoutAmount = 1000.0;

class RevenueBalanceScreen extends ConsumerStatefulWidget {
  const RevenueBalanceScreen({super.key});
  @override
  ConsumerState<RevenueBalanceScreen> createState() => _RevenueBalanceScreenState();
}

class _RevenueBalanceScreenState extends ConsumerState<RevenueBalanceScreen> {
  bool _requesting = false;

  Future<void> _requestPayout(double balance) async {
    setState(() => _requesting = true);
    await ref.read(payoutRepositoryProvider).requestPayout(balance);
    setState(() => _requesting = false);
    ref.invalidate(balanceProvider);
    ref.invalidate(payoutHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(balanceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายได้'),
        actions: [IconButton(icon: const Icon(Icons.history), onPressed: () => context.push(RoutePaths.payoutHistory))],
      ),
      body: balanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(message: 'โหลดยอดเงินไม่สำเร็จ', onRetry: () => ref.invalidate(balanceProvider)),
        data: (balance) {
          final canWithdraw = balance >= kMinPayoutAmount;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ยอดคงเหลือ', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text('฿${balance.toStringAsFixed(0)}', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.xl),
                  Tooltip(
                    message: canWithdraw ? '' : 'ยอดขั้นต่ำในการถอน ฿${kMinPayoutAmount.toStringAsFixed(0)}',
                    child: AppButton(
                      label: 'ขอถอนเงิน',
                      isLoading: _requesting,
                      onPressed: (!canWithdraw || _requesting) ? null : () => _requestPayout(balance),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('ขั้นต่ำ ฿${kMinPayoutAmount.toStringAsFixed(0)}', style: AppTextStyles.caption),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}