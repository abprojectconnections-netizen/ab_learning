import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/job_board_repository.dart';

final jobBoardRepositoryProvider = Provider<JobBoardRepository>((ref) {
  return FirebaseJobBoardRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

final openJobsProvider = FutureProvider.autoDispose<List<JobOpening>>(
    (ref) => ref.watch(jobBoardRepositoryProvider).openJobs());

final appliedJobIdsProvider = FutureProvider.autoDispose<Set<String>>(
    (ref) => ref.watch(jobBoardRepositoryProvider).appliedJobIds());
