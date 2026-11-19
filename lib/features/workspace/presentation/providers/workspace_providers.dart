import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/workspace_repositories.dart';
import '../../domain/workspace_models.dart';

final orgRepositoryProvider = Provider<OrgRepository>((ref) {
  return FirebaseOrgRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

final recruitmentRepositoryProvider = Provider<RecruitmentRepository>((ref) {
  return FirebaseRecruitmentRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return FirebaseAdminRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

// ---- Corporate ----
final staffMembershipProvider = FutureProvider.autoDispose<OrgMember?>(
    (ref) => ref.watch(orgRepositoryProvider).myStaffMembership());

final orgMembersProvider = FutureProvider.autoDispose<List<OrgMember>>((ref) async {
  final me = await ref.watch(staffMembershipProvider.future);
  if (me == null) return const [];
  return ref.watch(orgRepositoryProvider).members(me.orgId);
});

final learningPathsProvider = FutureProvider.autoDispose<List<LearningPath>>((ref) async {
  final me = await ref.watch(staffMembershipProvider.future);
  if (me == null) return const [];
  return ref.watch(orgRepositoryProvider).paths(me.orgId);
});

/// Active learning paths for the signed-in member (any role).
final myLearningPathsProvider = FutureProvider.autoDispose<List<LearningPath>>(
    (ref) => ref.watch(orgRepositoryProvider).myPaths());

final teamProgressProvider = FutureProvider.autoDispose<List<TeamMemberProgress>>(
    (ref) => ref.watch(orgRepositoryProvider).teamProgress());

// ---- Recruitment ----
final myJobsProvider = FutureProvider.autoDispose<List<JobPosting>>(
    (ref) => ref.watch(recruitmentRepositoryProvider).myJobs());

final jobApplicationsProvider = FutureProvider.autoDispose<List<JobApplication>>(
    (ref) => ref.watch(recruitmentRepositoryProvider).applications());

// ---- Administration ----
final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>(
    (ref) => ref.watch(adminRepositoryProvider).users());

final pendingInstructorApplicationsProvider =
    FutureProvider.autoDispose<List<InstructorApplication>>(
        (ref) => ref.watch(adminRepositoryProvider).pendingInstructorApplications());

final pendingCoursesProvider = FutureProvider.autoDispose<List<PendingCourse>>(
    (ref) => ref.watch(adminRepositoryProvider).pendingCourses());

final salesTodayProvider = FutureProvider.autoDispose<SalesToday>(
    (ref) => ref.watch(adminRepositoryProvider).salesToday());

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>(
    (ref) => ref.watch(adminRepositoryProvider).auditLog());
