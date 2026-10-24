// lib/features/payment/data/order_repository.dart
import '../domain/order_model.dart';

abstract class OrderRepository {
  Future<String> createOrder(String courseId, double amount); // TODO: Production เรียก Cloud Function createOrder()
  Future<OrderModel> getOrderById(String orderId);
  Future<void> confirmMockPayment(String orderId); // ใช้เฉพาะ DEV/BETA ปุ่ม "จำลองชำระเงิน"
}

class MockOrderRepository implements OrderRepository {
  final _orders = <String, OrderModel>{};

  @override
  Future<String> createOrder(String courseId, double amount) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final id = 'order-${DateTime.now().millisecondsSinceEpoch}';
    _orders[id] = OrderModel(id: id, courseId: courseId, courseTitle: 'คอร์สที่เลือกซื้อ', amount: amount, status: OrderStatus.pending, createdAt: DateTime.now());
    return id;
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _orders[orderId] ?? OrderModel(id: orderId, courseId: '-', courseTitle: '-', amount: 0, status: OrderStatus.pending, createdAt: DateTime.now());
  }

  @override
  Future<void> confirmMockPayment(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final existing = _orders[orderId];
    if (existing != null) {
      _orders[orderId] = OrderModel(id: existing.id, courseId: existing.courseId, courseTitle: existing.courseTitle, amount: existing.amount, status: OrderStatus.paid, createdAt: existing.createdAt);
    }
  }
}