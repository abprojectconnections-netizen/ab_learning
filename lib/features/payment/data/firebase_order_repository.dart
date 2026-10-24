import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/order_model.dart';
import 'order_repository.dart';

class FirebaseOrderRepository implements OrderRepository {
  FirebaseOrderRepository({
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
    if (uid == null) throw StateError('Sign in to manage orders.');
    return uid;
  }

  @override
  Future<String> createOrder(String courseId, double amount) async {
    final courseRef = _firestore.collection('courses').doc(courseId);
    final course = await courseRef.get();
    if (!course.exists || course.data()?['status'] != 'published') {
      throw StateError('This course is not available for enrollment.');
    }
    final courseData = course.data()!;
    final price = (courseData['price'] as num?)?.toDouble() ?? 0;
    if (price != amount) {
      throw StateError('Course price changed. Refresh and try again.');
    }
    final ref = _firestore.collection('payment_mock').doc();
    await ref.set({
      'studentId': _uid,
      'courseId': courseId,
      'amount': price,
      'currency': 'THB',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    final snapshot =
        await _firestore.collection('payment_mock').doc(orderId).get();
    if (!snapshot.exists) {
      throw StateError('Order was not found.');
    }
    final data = snapshot.data()!;
    if (data['studentId'] != _uid) {
      throw StateError('You cannot access this order.');
    }
    final courseId = data['courseId'] as String? ?? '';
    final course = await _firestore.collection('courses').doc(courseId).get();
    final state = switch (data['status']) {
      'success' || 'paid' => OrderStatus.paid,
      'failed' => OrderStatus.failed,
      'cancelled' => OrderStatus.cancelled,
      'refunded' => OrderStatus.refunded,
      _ => OrderStatus.pending,
    };
    return OrderModel(
      id: snapshot.id,
      courseId: courseId,
      courseTitle: course.data()?['title'] as String? ?? 'Course',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: state,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<void> confirmMockPayment(String orderId) async {
    await _functions
        .httpsCallable('confirmMockPayment')
        .call({'transactionId': orderId});
  }
}
