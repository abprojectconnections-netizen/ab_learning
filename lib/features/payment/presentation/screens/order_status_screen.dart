// lib/features/payment/presentation/screens/order_status_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/order_providers.dart';
import '../../domain/order_model.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class OrderStatusScreen extends ConsumerWidget {
  final String orderId;
  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('สถานะคำสั่งซื้อ')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(
            message: 'โหลดสถานะไม่สำเร็จ',
            onRetry: () => ref.invalidate(orderByIdProvider(orderId))),
        data: (order) {
          final (icon, statusKind) = switch (order.status) {
            OrderStatus.pending => (Icons.hourglass_top, StatusKind.pending),
            OrderStatus.paid => (Icons.check_circle, StatusKind.paid),
            OrderStatus.failed => (Icons.error, StatusKind.failed),
            OrderStatus.cancelled => (Icons.cancel, StatusKind.failed),
            OrderStatus.refunded => (Icons.undo, StatusKind.refunded),
          };
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: AppSpacing.md),
                  Text('คำสั่งซื้อ #${order.id}', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  StatusBadge(kind: statusKind),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
