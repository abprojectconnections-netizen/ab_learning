// lib/features/revenue/data/payout_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/payout_model.dart';

abstract class PayoutRepository {
  Future<RevenueSummary> getSummary();
  Future<void> requestPayout(double amount);
  Future<List<PayoutModel>> getPayoutHistory();
  Future<List<SalesRecord>> getSalesRecords();
}

class FirebasePayoutRepository implements PayoutRepository {
  FirebasePayoutRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to view revenue.');
    return uid;
  }

  @override
  Future<RevenueSummary> getSummary() async {
    final response = await _functions
        .httpsCallable('getRevenueSummary')
        .call<Map<Object?, Object?>>();
    final d = response.data;
    double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
    return RevenueSummary(
      gross: n('gross'),
      earned: n('earned'),
      reserved: n('reserved'),
      balance: n('balance'),
      minPayout: n('minPayout'),
    );
  }

  @override
  Future<void> requestPayout(double amount) async {
    await _functions.httpsCallable('requestPayout').call({'amount': amount});
  }

  @override
  Future<List<PayoutModel>> getPayoutHistory() async {
    final result = await _firestore
        .collection('payouts')
        .where('instructorId', isEqualTo: _uid)
        .orderBy('requestedAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return PayoutModel(
        id: doc.id,
        amount: (d['amount'] as num?)?.toDouble() ?? 0,
        status: switch (d['status']) {
          'approved' => PayoutStatus.approved,
          'paid' => PayoutStatus.paid,
          'rejected' => PayoutStatus.rejected,
          _ => PayoutStatus.pending,
        },
        requestedAt: (d['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<List<SalesRecord>> getSalesRecords() async {
    final result = await _firestore
        .collection('sales')
        .where('instructorId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return SalesRecord(
        date: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        courseTitle: d['courseTitle'] as String? ?? '',
        buyerName: d['buyerName'] as String? ?? '',
        amount: (d['amount'] as num?)?.toDouble() ?? 0,
        status: switch (d['status']) {
          'refunded' => OrderStatusLite.refunded,
          'pending' => OrderStatusLite.pending,
          _ => OrderStatusLite.paid,
        },
      );
    }).toList();
  }
}
