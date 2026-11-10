// lib/features/learning/presentation/providers/progress_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../data/firebase_progress_repository.dart';
import '../../data/progress_repository.dart';
import '../../domain/progress_model.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return FirebaseProgressRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

final courseProgressProvider =
    FutureProvider.autoDispose.family<ProgressModel, String>((ref, courseId) {
  return ref.watch(progressRepositoryProvider).getProgress(courseId);
});

final myEnrolledCoursesProvider =
    FutureProvider.autoDispose<List<EnrolledCourseSummary>>((ref) {
  return ref.watch(progressRepositoryProvider).getMyEnrolledCourses();
});

/// Course completion (0-100) = completed lectures / total lectures.
final courseCompletionPercentProvider =
    FutureProvider.autoDispose.family<double, String>((ref, courseId) async {
  final course = await ref.watch(courseByIdProvider(courseId).future);
  final progress = await ref.watch(courseProgressProvider(courseId).future);
  if (course == null) return 0;
  final ids = course.sections.expand((s) => s.lectures).map((l) => l.id).toSet();
  if (ids.isEmpty) return 0;
  final done = progress.completedLectureIds.where(ids.contains).length;
  return done * 100 / ids.length;
});
