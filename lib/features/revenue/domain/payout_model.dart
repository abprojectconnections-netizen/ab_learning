// lib/features/revenue/domain/payout_model.dart
enum PayoutStatus { pending, approved, paid, rejected }

/// Server-computed revenue summary (see getRevenueSummary function).
class RevenueSummary {
  final double gross;
  final double earned;
  final double reserved;
  final double balance;
  final double minPayout;
  const RevenueSummary({
    required this.gross,
    required this.earned,
    required this.reserved,
    required this.balance,
    required this.minPayout,
  });
}

class PayoutModel {
  final String id;
  final double amount;
  final PayoutStatus status;
  final DateTime requestedAt;
  const PayoutModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.requestedAt,
  });
}

class SalesRecord {
  final DateTime date;
  final String courseTitle;
  final String buyerName;
  final double amount;
  final OrderStatusLite status;
  const SalesRecord({
    required this.date,
    required this.courseTitle,
    required this.buyerName,
    required this.amount,
    required this.status,
  });
}

enum OrderStatusLite { paid, pending, refunded }