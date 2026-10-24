// lib/features/payment/domain/order_model.dart
enum OrderStatus { pending, paid, failed, cancelled, refunded }

class OrderModel {
  final String id;
  final String courseId;
  final String courseTitle;
  final double amount;
  final OrderStatus status;
  final DateTime createdAt;
  const OrderModel({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.amount,
    required this.status,
    required this.createdAt,
  });
}
