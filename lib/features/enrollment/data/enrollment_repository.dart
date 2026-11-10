// lib/features/enrollment/data/enrollment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class EnrollmentRepository {
  /// Course ids the signed-in learner has an active enrollment for.
  Stream<Set<String>> watchEnrolledCourseIds();

  /// Client-side enrollment, allowed by firestore.rules for FREE published
  /// courses only. Paid enrollment is activated by the server after payment.
  Future<void> enrollFreeCourse(String courseId);
}
class FirebaseEnrollmentRepository implements EnrollmentRepository {
  FirebaseEnrollmentRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to manage enrollments.');
    return uid;
  }

  @override
  Stream<Set<String>> watchEnrolledCourseIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <String>{});
    return _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs
            .map((d) => d.data()['courseId'] as String?)
            .whereType<String>()
            .toSet());
  }

  @override
  Future<void> enrollFreeCourse(String courseId) {
    // Doc id format {studentUid}_{courseId}; keys limited by rules whitelist.
    return _firestore.collection('enrollments').doc('${_uid}_$courseId').set({
      'studentId': _uid,
      'courseId': courseId,
      'status': 'active',
      'enrolledAt': FieldValue.serverTimestamp(),
    });
  }
}
