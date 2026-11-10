// lib/features/revenue/presentation/providers/payout_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payout_repository.dart';
import '../../domain/payout_model.dart';

final payoutRepositoryProvider = Provider<PayoutRepository>((ref) {
  return FirebasePayoutRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

final revenueSummaryProvider = FutureProvider.autoDispose<RevenueSummary>((ref) {
  return ref.watch(payoutRepositoryProvider).getSummary();
});

final payoutHistoryProvider = FutureProvider.autoDispose<List<PayoutModel>>((ref) {
  return ref.watch(payoutRepositoryProvider).getPayoutHistory();
});

final salesRecordsProvider = FutureProvider.autoDispose<List<SalesRecord>>((ref) {
  return ref.watch(payoutRepositoryProvider).getSalesRecords();
});
