// lib/features/workspace/data/workspace_repositories.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/workspace_models.dart';

String _uidOf(FirebaseAuth auth) {
  final uid = auth.currentUser?.uid;
  if (uid == null) throw StateError('Sign in required.');
  return uid;
}

// ---------------------------------------------------------------------------
// Corporate learning
// ---------------------------------------------------------------------------

abstract class OrgRepository {
  /// The caller's active membership (admin or manager), or null.
  Future<OrgMember?> myStaffMembership();
  Future<List<OrgMember>> members(String orgId);
  Future<void> addMember(String email, {bool manager = false});
  Future<void> setMemberStatus(String orgId, String uid, String status);
  Future<List<LearningPath>> paths(String orgId);
  Future<void> createPath(String orgId,
      {required String title, required String description});
  Future<void> setPathStatus(String pathId, String status);
  Future<List<TeamMemberProgress>> teamProgress();
}

class FirebaseOrgRepository implements OrgRepository {
  FirebaseOrgRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _db = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  OrgMember _member(Map<String, dynamic> d) => OrgMember(
        orgId: d['orgId'] as String? ?? '',
        uid: d['uid'] as String? ?? '',
        email: d['email'] as String? ?? '',
        displayName: d['displayName'] as String? ?? '',
        role: d['role'] as String? ?? 'member',
        status: d['status'] as String? ?? 'active',
      );

  @override
  Future<OrgMember?> myStaffMembership() async {
    final result = await _db
        .collection('org_members')
        .where('uid', isEqualTo: _uidOf(_auth))
        .where('status', isEqualTo: 'active')
        .get();
    for (final doc in result.docs) {
      final m = _member(doc.data());
      if (m.role == 'admin' || m.role == 'manager') return m;
    }
    return null;
  }

  @override
  Future<List<OrgMember>> members(String orgId) async {
    final result = await _db
        .collection('org_members')
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((d) => _member(d.data())).toList();
  }

  @override
  Future<void> addMember(String email, {bool manager = false}) async {
    await _functions
        .httpsCallable('addOrgMember')
        .call({'email': email, 'role': manager ? 'manager' : 'member'});
  }

  @override
  Future<void> setMemberStatus(String orgId, String uid, String status) {
    return _db.collection('org_members').doc('${orgId}_$uid').update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<LearningPath>> paths(String orgId) async {
    final result = await _db
        .collection('learning_paths')
        .where('orgId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return LearningPath(
        id: doc.id,
        orgId: orgId,
        title: d['title'] as String? ?? '',
        description: d['description'] as String? ?? '',
        status: d['status'] as String? ?? 'draft',
      );
    }).toList();
  }

  @override
  Future<void> createPath(String orgId,
      {required String title, required String description}) async {
    await _db.collection('learning_paths').add({
      'orgId': orgId,
      'title': title.trim(),
      'description': description.trim(),
      'status': 'draft',
      'createdBy': _uidOf(_auth),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setPathStatus(String pathId, String status) {
    return _db.collection('learning_paths').doc(pathId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<TeamMemberProgress>> teamProgress() async {
    final response = await _functions
        .httpsCallable('getOrgTeamProgress')
        .call<Map<Object?, Object?>>();
    final rows = (response.data['members'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    return rows
        .map((r) => TeamMemberProgress(
              uid: r['uid'] as String? ?? '',
              displayName: r['displayName'] as String? ?? '',
              email: r['email'] as String? ?? '',
              memberStatus: r['memberStatus'] as String? ?? 'active',
              enrolledCourses: (r['enrolledCourses'] as num?)?.toInt() ?? 0,
              completedCourses: (r['completedCourses'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Recruitment
// ---------------------------------------------------------------------------

abstract class RecruitmentRepository {
  Future<List<JobPosting>> myJobs();
  Future<void> createJob({required String title, required String location});
  Future<void> setJobStatus(String jobId, String status);
  Future<List<JobApplication>> applications();
  Future<void> setApplicationStatus(String applicationId, String status);
}

class FirebaseRecruitmentRepository implements RecruitmentRepository {
  FirebaseRecruitmentRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _db = firestore,
        _auth = auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Future<List<JobPosting>> myJobs() async {
    final result = await _db
        .collection('job_postings')
        .where('employerId', isEqualTo: _uidOf(_auth))
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return JobPosting(
        id: doc.id,
        title: d['title'] as String? ?? '',
        location: d['location'] as String? ?? '',
        status: d['status'] as String? ?? 'open',
      );
    }).toList();
  }

  @override
  Future<void> createJob({required String title, required String location}) async {
    await _db.collection('job_postings').add({
      'employerId': _uidOf(_auth),
      'title': title.trim(),
      'location': location.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setJobStatus(String jobId, String status) {
    return _db.collection('job_postings').doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<JobApplication>> applications() async {
    final result = await _db
        .collection('job_applications')
        .where('employerId', isEqualTo: _uidOf(_auth))
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return JobApplication(
        id: doc.id,
        jobId: d['jobId'] as String? ?? '',
        candidateName: d['candidateName'] as String? ?? '',
        status: d['status'] as String? ?? 'new',
      );
    }).toList();
  }

  @override
  Future<void> setApplicationStatus(String applicationId, String status) {
    return _db.collection('job_applications').doc(applicationId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ---------------------------------------------------------------------------
// Administration
// ---------------------------------------------------------------------------

abstract class AdminRepository {
  Future<List<AdminUser>> users();
  Future<void> setUserStatus(String uid, String status);
  Future<void> setUserRole(String uid, String role); // super admin only
  Future<List<InstructorApplication>> pendingInstructorApplications();
  Future<void> approveInstructorApplication(String applicationId);
  Future<List<PendingCourse>> pendingCourses();
  Future<void> reviewCourse(String courseId, {required bool approve});
  Future<SalesToday> salesToday();
  Future<List<AuditEntry>> auditLog({int limit = 50});
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _db = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  @override
  Future<List<AdminUser>> users() async {
    final result = await _db.collection('users').limit(200).get();
    return result.docs.map((doc) {
      final d = doc.data();
      return AdminUser(
        uid: doc.id,
        email: d['email'] as String? ?? '',
        displayName: d['displayName'] as String? ?? '',
        role: d['role'] as String? ?? 'learner',
        status: d['status'] as String? ?? 'active',
      );
    }).toList();
  }

  @override
  Future<void> setUserStatus(String uid, String status) async {
    await _functions
        .httpsCallable('adminSetUserStatus')
        .call({'uid': uid, 'status': status});
  }

  @override
  Future<void> setUserRole(String uid, String role) async {
    await _functions.httpsCallable('setUserRole').call({'uid': uid, 'role': role});
  }

  @override
  Future<List<InstructorApplication>> pendingInstructorApplications() async {
    final result = await _db
        .collection('instructor_applications')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return InstructorApplication(
        id: doc.id,
        uid: d['uid'] as String? ?? '',
        displayName: d['displayName'] as String? ?? '',
        experience: d['experience'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<void> approveInstructorApplication(String applicationId) async {
    await _functions
        .httpsCallable('approveInstructorApplication')
        .call({'applicationId': applicationId});
  }

  @override
  Future<List<PendingCourse>> pendingCourses() async {
    final result = await _db
        .collection('courses')
        .where('status', isEqualTo: 'pending_review')
        .orderBy('updatedAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return PendingCourse(
        id: doc.id,
        title: d['title'] as String? ?? '',
        instructorName: d['instructorName'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<void> reviewCourse(String courseId, {required bool approve}) {
    return _db.collection('courses').doc(courseId).update({
      'status': approve ? 'published' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': _uidOf(_auth),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<SalesToday> salesToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final result = await _db
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();
    var total = 0.0;
    for (final doc in result.docs) {
      if (doc.data()['status'] == 'paid') {
        total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return SalesToday(count: result.size, total: total);
  }

  @override
  Future<List<AuditEntry>> auditLog({int limit = 50}) async {
    final result = await _db
        .collection('audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return AuditEntry(
        id: doc.id,
        action: d['action'] as String? ?? '',
        actorUid: d['actorUid'] as String? ?? '',
        targetType: d['targetType'] as String? ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }
}
