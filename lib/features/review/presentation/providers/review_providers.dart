import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/review_repository.dart';
import '../../domain/review_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return FirebaseReviewRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

final courseReviewsProvider =
    FutureProvider.autoDispose.family<List<ReviewModel>, String>((ref, courseId) {
  return ref.watch(reviewRepositoryProvider).getReviews(courseId);
});
