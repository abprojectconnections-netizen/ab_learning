import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/instructor_application_repository.dart';

final instructorApplicationRepositoryProvider =
    Provider<InstructorApplicationRepository>((ref) {
  return FirebaseInstructorApplicationRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

final myInstructorApplicationProvider =
    FutureProvider.autoDispose<InstructorApplicationStatus>((ref) {
  return ref.watch(instructorApplicationRepositoryProvider).myStatus();
});
