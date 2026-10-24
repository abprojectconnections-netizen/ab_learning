// lib/features/revenue/data/payout_repository.dart
import '../domain/payout_model.dart';

abstract class PayoutRepository {
  Future<double> getBalance();
  Future<void> requestPayout(double amount); // TODO: เรียก Cloud Function requestPayout()
  Future<List<PayoutModel>> getPayoutHistory();
  Future<List<SalesRecord>> getSalesRecords();
}

class MockPayoutRepository implements PayoutRepository {
  @override
  Future<double> getBalance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 12500;
  }

  @override
  Future<void> requestPayout(double amount) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<List<PayoutModel>> getPayoutHistory() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      PayoutModel(id: 'p1', amount: 5000, status: PayoutStatus.paid, requestedAt: DateTime(2025, 1, 10)),
      PayoutModel(id: 'p2', amount: 3000, status: PayoutStatus.pending, requestedAt: DateTime(2025, 1, 1)),
    ];
  }

  @override
  Future<List<SalesRecord>> getSalesRecords() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      SalesRecord(date: DateTime(2025, 1, 9), courseTitle: 'Flutter Intro', buyerName: 'คุณเอ', amount: 990, status: OrderStatusLite.paid),
      SalesRecord(date: DateTime(2025, 1, 8), courseTitle: 'UX Design 101', buyerName: 'คุณบี', amount: 1200, status: OrderStatusLite.paid),
    ];
  }
}