// test/support/fake_workspace.dart
//
// Stateful in-memory repositories for widget tests of the role workspaces.
import 'package:ab_learning/features/workspace/data/workspace_repositories.dart';
import 'package:ab_learning/features/workspace/domain/workspace_models.dart';

class FakeOrgRepository implements OrgRepository {
  final List<OrgMember> _members = [
    const OrgMember(orgId: 'org1', uid: 'admin-1', email: 'admin@acme.co', displayName: 'Acme Admin', role: 'admin', status: 'active'),
  ];
  final List<LearningPath> _paths = [];

  @override
  Future<OrgMember?> myStaffMembership() async => _members.first;

  @override
  Future<List<OrgMember>> members(String orgId) async => List.of(_members);

  @override
  Future<void> addMember(String email, {bool manager = false}) async {
    _members.add(OrgMember(
      orgId: 'org1',
      uid: 'uid-${_members.length}',
      email: email,
      displayName: email.split('@').first,
      role: manager ? 'manager' : 'member',
      status: 'active',
    ));
  }

  @override
  Future<void> setMemberStatus(String orgId, String uid, String status) async {
    final i = _members.indexWhere((m) => m.uid == uid);
    final m = _members[i];
    _members[i] = OrgMember(orgId: m.orgId, uid: m.uid, email: m.email, displayName: m.displayName, role: m.role, status: status);
  }

  @override
  Future<List<LearningPath>> paths(String orgId) async => List.of(_paths);

  @override
  Future<void> createPath(String orgId, {required String title, required String description}) async {
    _paths.add(LearningPath(id: 'p${_paths.length}', orgId: orgId, title: title, description: description, status: 'draft'));
  }

  @override
  Future<void> setPathStatus(String pathId, String status) async {}

  @override
  Future<List<TeamMemberProgress>> teamProgress() async => _members
      .map((m) => TeamMemberProgress(uid: m.uid, displayName: m.displayName, email: m.email, memberStatus: m.status, enrolledCourses: 0, completedCourses: 0))
      .toList();
}

class FakeRecruitmentRepository implements RecruitmentRepository {
  final List<JobPosting> _jobs = [];

  @override
  Future<List<JobPosting>> myJobs() async => List.of(_jobs);

  @override
  Future<void> createJob({required String title, required String location}) async {
    _jobs.add(JobPosting(id: 'j${_jobs.length}', title: title, location: location, status: 'open'));
  }

  @override
  Future<void> setJobStatus(String jobId, String status) async {}

  @override
  Future<List<JobApplication>> applications() async => const [];

  @override
  Future<void> setApplicationStatus(String applicationId, String status) async {}
}

class FakeAdminRepository implements AdminRepository {
  final List<PendingCourse> _pending = [
    const PendingCourse(id: 'c1', title: 'Flutter พื้นฐาน', instructorName: 'Somchai'),
  ];
  String? lastReview;

  @override
  Future<List<AdminUser>> users() async => const [];

  @override
  Future<void> setUserStatus(String uid, String status) async {}

  @override
  Future<void> setUserRole(String uid, String role) async {}

  @override
  Future<List<InstructorApplication>> pendingInstructorApplications() async => const [];

  @override
  Future<void> approveInstructorApplication(String applicationId) async {}

  @override
  Future<List<PendingCourse>> pendingCourses() async => List.of(_pending);

  @override
  Future<void> reviewCourse(String courseId, {required bool approve}) async {
    _pending.removeWhere((c) => c.id == courseId);
    lastReview = approve ? 'published' : 'rejected';
  }

  @override
  Future<SalesToday> salesToday() async => const SalesToday(count: 0, total: 0);

  @override
  Future<List<AuditEntry>> auditLog({int limit = 50}) async => const [];
}
