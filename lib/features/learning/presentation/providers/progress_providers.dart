// lib/features/learning/presentation/providers/progress_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/config/app_config.dart';
import '../../data/firebase_progress_repository.dart';
import '../../data/progress_repository.dart';
import '../../domain/progress_model.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockBackend) return MockProgressRepository();
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
