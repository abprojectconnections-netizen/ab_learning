// lib/features/revenue/presentation/providers/payout_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payout_repository.dart';
import '../../domain/payout_model.dart';

final payoutRepositoryProvider = Provider<PayoutRepository>((ref) => MockPayoutRepository());

final balanceProvider = FutureProvider.autoDispose<double>((ref) {
  return ref.watch(payoutRepositoryProvider).getBalance();
});

final payoutHistoryProvider = FutureProvider.autoDispose<List<PayoutModel>>((ref) {
  return ref.watch(payoutRepositoryProvider).getPayoutHistory();
});

final salesRecordsProvider = FutureProvider.autoDispose<List<SalesRecord>>((ref) {
  return ref.watch(payoutRepositoryProvider).getSalesRecords();
});