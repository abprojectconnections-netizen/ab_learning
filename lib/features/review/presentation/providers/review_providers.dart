import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/review_model.dart';

class ReviewNotifier extends StateNotifier<List<ReviewModel>> {
  ReviewNotifier() : super([
    ReviewModel(
      id: 'rev-1',
      courseId: 'course-0',
      userName: 'สมชาย ใจดี',
      rating: 5.0,
      comment: 'เนื้อหาเข้าใจง่าย สอนดีมากครับ แนะนำเลย!',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ]);

  void addReview(String courseId, double rating, String comment, String userName) {
    final newReview = ReviewModel(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      courseId: courseId,
      userName: userName,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    state = [newReview, ...state];
  }
}

final reviewListProvider = StateNotifierProvider<ReviewNotifier, List<ReviewModel>>((ref) {
  return ReviewNotifier();
});