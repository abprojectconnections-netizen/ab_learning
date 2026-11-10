import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/enrollment_repository.dart';

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  return FirebaseEnrollmentRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

/// Re-subscribes whenever the signed-in user changes.
final enrolledCourseIdsProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(authStateProvider.select((a) => a.uid));
  return ref.watch(enrollmentRepositoryProvider).watchEnrolledCourseIds();
});

final isEnrolledProvider = Provider.family<bool, String>((ref, courseId) {
  return ref.watch(enrolledCourseIdsProvider).valueOrNull?.contains(courseId) ??
      false;
});
