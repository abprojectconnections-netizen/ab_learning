// lib/features/jobs/data/job_board_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobOpening {
  final String id;
  final String title;
  final String location;
  const JobOpening({required this.id, required this.title, required this.location});
}

abstract class JobBoardRepository {
  Future<List<JobOpening>> openJobs();

  /// Ids of the jobs the signed-in user has already applied to.
  Future<Set<String>> appliedJobIds();

  Future<void> apply(String jobId);
}

class FirebaseJobBoardRepository implements JobBoardRepository {
  FirebaseJobBoardRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _db = firestore,
        _auth = auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to apply for jobs.');
    return uid;
  }

  @override
  Future<List<JobOpening>> openJobs() async {
    final result = await _db
        .collection('job_postings')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return JobOpening(
        id: doc.id,
        title: d['title'] as String? ?? '',
        location: d['location'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<Set<String>> appliedJobIds() async {
    final result = await _db
        .collection('job_applications')
        .where('candidateId', isEqualTo: _uid)
        .get();
    return result.docs.map((d) => d.data()['jobId'] as String?).whereType<String>().toSet();
  }

  @override
  Future<void> apply(String jobId) async {
    final uid = _uid;
    final job = await _db.collection('job_postings').doc(jobId).get();
    if (!job.exists || job.data()?['status'] != 'open') {
      throw StateError('This position is no longer open.');
    }
    final profile = await _db.collection('users').doc(uid).get();
    // Doc id {jobId}_{uid} makes a second application impossible; the rules
    // also check the employer and display name against trusted documents.
    await _db.collection('job_applications').doc('${jobId}_$uid').set({
      'jobId': jobId,
      'employerId': job.data()!['employerId'],
      'candidateId': uid,
      'candidateName': profile.data()?['displayName'] as String? ?? '',
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
