// lib/features/marketplace/presentation/providers/course_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../data/course_repository.dart';
import '../../data/firebase_course_repository.dart';
import '../../data/rest_course_repository.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_providers.dart';
import '../../domain/course_model.dart';

/// Go + MySQL API when API_BASE_URL is defined, Firebase otherwise.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  if (ref.watch(useRestBackendProvider)) {
    return RestCourseRepository(ref.watch(apiClientProvider));
  }
  return FirebaseCourseRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

final publishedCoursesProvider =
    FutureProvider.autoDispose<List<CourseModel>>((ref) {
  return ref.watch(courseRepositoryProvider).getPublishedCourses();
});

final courseByIdProvider =
    FutureProvider.autoDispose.family<CourseModel?, String>((ref, courseId) {
  return ref.watch(courseRepositoryProvider).getCourseById(courseId);
});

final searchResultsProvider =
    FutureProvider.autoDispose.family<List<CourseModel>, String>((ref, query) {
  return ref.watch(courseRepositoryProvider).searchCourses(query);
});

final categoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(courseRepositoryProvider).getCategories();
});

final instructorCoursesProvider = FutureProvider.autoDispose
    .family<List<CourseModel>, String>((ref, instructorId) {
  return ref.watch(courseRepositoryProvider).getInstructorCourses(instructorId);
});
