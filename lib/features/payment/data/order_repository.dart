// lib/features/payment/data/order_repository.dart
import '../domain/order_model.dart';

abstract class OrderRepository {
  Future<String> createOrder(String courseId, double amount); // TODO: Production เรียก Cloud Function createOrder()
  Future<OrderModel> getOrderById(String orderId);
  Future<void> confirmMockPayment(String orderId); // DEV project only

  /// Creates a Stripe Checkout Session server-side and returns its hosted URL.
  /// Enrollment is activated by the verified Stripe webhook, never the client.
  Future<String> startCheckout(String orderId, String returnUrl);
}
