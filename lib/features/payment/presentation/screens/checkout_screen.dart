// lib/features/payment/presentation/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../providers/order_providers.dart';
import '../../../../core/state/app_store.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CheckoutScreen({super.key, required this.courseId});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum PaymentMethod { mock, transfer }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _method = PaymentMethod.mock;
  bool _processing = false;

  Future<void> _confirmOrder(double amount) async {
    setState(() => _processing = true);
    final orderId = await ref
        .read(orderRepositoryProvider)
        .createOrder(widget.courseId, amount);
    if (_method == PaymentMethod.mock) {
      await ref.read(orderRepositoryProvider).confirmMockPayment(orderId);
      // ⭐ ปลดล็อกคอร์สเข้าสู่ AppStore กลางทันที
      ref.read(appStoreProvider.notifier).enrollCourse(widget.courseId);
    }
    if (mounted) {
      context.go(RoutePaths.orderStatus.replaceFirst(':orderId', orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseByIdProvider(widget.courseId));
    return Scaffold(
      appBar: AppBar(title: const Text('สรุปคำสั่งซื้อ')),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const AppErrorState(message: 'โหลดข้อมูลไม่สำเร็จ'),
        data: (course) {
          if (course == null) {
            return const AppErrorState(message: 'ไม่พบคอร์สนี้');
          }
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.sm),
                Text('ราคา: ฿${course.price.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge),
                const Divider(height: 32),
                Text('วิธีชำระเงิน:', style: AppTextStyles.bodyMedium),
                RadioGroup<PaymentMethod>(
                  groupValue: _method,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _method = value);
                    }
                  },
                  child: const Column(
                    children: [
                      RadioListTile<PaymentMethod>(
                        value: PaymentMethod.mock,
                        title: Text('Mock payment (Demo)'),
                      ),
                      RadioListTile<PaymentMethod>(
                        value: PaymentMethod.transfer,
                        title: Text('Bank transfer + receipt'),
                      ),
                    ],
                  ),
                ),
                if (_method == PaymentMethod.transfer) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'แนบสลิปการโอนเงิน',
                    icon: Icons.attach_file,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ],
                const Spacer(),
                AppButton(
                  label: 'ยืนยันคำสั่งซื้อ',
                  isLoading: _processing,
                  fullWidth: true,
                  onPressed:
                      _processing ? null : () => _confirmOrder(course.price),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
