// lib/features/review/data/review_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/review_model.dart';

abstract class ReviewRepository {
  Future<List<ReviewModel>> getReviews(String courseId);
  Future<void> submitReview({
    required String courseId,
    required int rating,
    required String comment,
  });
}

class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<List<ReviewModel>> getReviews(String courseId) async {
    final result = await _firestore
        .collection('course_reviews')
        .where('courseId', isEqualTo: courseId)
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return ReviewModel(
        id: doc.id,
        courseId: courseId,
        userName: d['studentName'] as String? ?? '',
        rating: (d['rating'] as num?)?.toDouble() ?? 0,
        comment: d['comment'] as String? ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> submitReview({
    required String courseId,
    required int rating,
    required String comment,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to review a course.');
    // Rules require the name to match users/{uid}.displayName.
    final profile = await _firestore.collection('users').doc(uid).get();
    await _firestore.collection('course_reviews').doc('${uid}_$courseId').set({
      'studentId': uid,
      'studentName': profile.data()?['displayName'] as String? ?? '',
      'courseId': courseId,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
