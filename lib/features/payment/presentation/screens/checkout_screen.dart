// lib/features/payment/presentation/screens/checkout_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../providers/order_providers.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
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

enum PaymentMethod { card, mock }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _method = PaymentMethod.card;
  bool _processing = false;

  Future<void> _confirmOrder(double amount) async {
    setState(() => _processing = true);
    try {
      if (amount == 0) {
        // Free course: rules allow client-side enrollment for price == 0 only.
        await ref
            .read(enrollmentRepositoryProvider)
            .enrollFreeCourse(widget.courseId);
        if (mounted) {
          context.go(RoutePaths.courseDetail
              .replaceFirst(':courseId', widget.courseId));
        }
        return;
      }
      final orders = ref.read(orderRepositoryProvider);
      final orderId = await orders.createOrder(widget.courseId, amount);
      final statusPath =
          RoutePaths.orderStatus.replaceFirst(':orderId', orderId);
      if (_method == PaymentMethod.mock) {
        // DEV project only: the callable activates the enrollment server-side.
        await orders.confirmMockPayment(orderId);
      } else {
        // Hosted Stripe Checkout; the signed webhook activates the enrollment.
        const appUrl = String.fromEnvironment('WEB_APP_URL');
        final returnUrl = kIsWeb
            ? '${Uri.base.origin}${Uri.base.path}#$statusPath'
            : '$appUrl/#$statusPath';
        final checkoutUrl = await orders.startCheckout(orderId, returnUrl);
        final launched = await launchUrl(Uri.parse(checkoutUrl),
            webOnlyWindowName: '_self');
        if (!launched) throw StateError('Could not open the payment page.');
        return;
      }
      if (mounted) {
        context.go(statusPath);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ทำรายการไม่สำเร็จ กรุณาลองใหม่')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
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
                  child: Column(
                    children: [
                      const RadioListTile<PaymentMethod>(
                        value: PaymentMethod.card,
                        title: Text('บัตรเครดิต/เดบิต / PromptPay (Stripe)'),
                      ),
                      if (ref.watch(appConfigProvider).environment ==
                          AppEnvironment.dev)
                        const RadioListTile<PaymentMethod>(
                          value: PaymentMethod.mock,
                          title: Text('Mock payment (DEV เท่านั้น)'),
                        ),
                    ],
                  ),
                ),
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
