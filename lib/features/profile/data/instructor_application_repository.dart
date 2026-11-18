// lib/features/profile/data/instructor_application_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum InstructorApplicationStatus { none, pending, approved, rejected }

abstract class InstructorApplicationRepository {
  /// Status of the signed-in user's application, [InstructorApplicationStatus.none]
  /// when they have not applied.
  Future<InstructorApplicationStatus> myStatus();

  /// Submits a pending application. The document id is the user's uid, so a
  /// user can only ever have one application (re-submitting is denied by rules).
  Future<void> apply({required String displayName, required String experience});
}

class FirebaseInstructorApplicationRepository
    implements InstructorApplicationRepository {
  FirebaseInstructorApplicationRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _db = firestore,
        _auth = auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required.');
    return uid;
  }

  @override
  Future<InstructorApplicationStatus> myStatus() async {
    // A query (not a get) so the rule can evaluate resource.data.uid even when
    // no application exists yet.
    final result = await _db
        .collection('instructor_applications')
        .where('uid', isEqualTo: _uid)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return InstructorApplicationStatus.none;
    return switch (result.docs.first.data()['status']) {
      'approved' => InstructorApplicationStatus.approved,
      'rejected' => InstructorApplicationStatus.rejected,
      _ => InstructorApplicationStatus.pending,
    };
  }

  @override
  Future<void> apply({
    required String displayName,
    required String experience,
  }) {
    final trimmed = experience.trim();
    if (trimmed.length < 20) {
      throw ArgumentError('Please describe your experience (at least 20 characters).');
    }
    return _db.collection('instructor_applications').doc(_uid).set({
      'uid': _uid,
      'displayName': displayName.trim(),
      'experience': trimmed,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
