import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/progress_model.dart';
import 'progress_repository.dart';

class FirebaseProgressRepository implements ProgressRepository {
  FirebaseProgressRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to view learning progress.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _progress =>
      _firestore.collection('users').doc(_uid).collection('progress');

  @override
  Future<ProgressModel> getProgress(String courseId) async {
    final result = await _progress.where('courseId', isEqualTo: courseId).get();
    if (result.docs.isEmpty) return ProgressModel(courseId: courseId);
    final completed = <String>[];
    String? lastId;
    DateTime? lastUpdate;
    var percentSum = 0.0;
    for (final doc in result.docs) {
      final data = doc.data();
      if (data['completed'] == true) completed.add(doc.id);
      percentSum += (data['percentComplete'] as num?)?.toDouble() ?? 0;
      final updated = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updated != null &&
          (lastUpdate == null || updated.isAfter(lastUpdate))) {
        lastUpdate = updated;
        lastId = doc.id;
      }
    }
    return ProgressModel(
      courseId: courseId,
      completedLectureIds: completed,
      lastWatchedLectureId: lastId,
      percentComplete: percentSum / result.docs.length,
    );
  }

  @override
  Future<List<EnrolledCourseSummary>> getMyEnrolledCourses() async {
    final enrollments = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .get();
    final summaries = <EnrolledCourseSummary>[];
    for (final enrollment in enrollments.docs) {
      final courseId = enrollment.data()['courseId'] as String?;
      if (courseId == null || courseId.isEmpty) continue;
      final courseSnapshot =
          await _firestore.collection('courses').doc(courseId).get();
      if (!courseSnapshot.exists) continue;
      final data = courseSnapshot.data()!;
      final progress = await getProgress(courseId);
      summaries.add(EnrolledCourseSummary(
        courseId: courseId,
        title: data['title'] as String? ?? '',
        thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
        percentComplete: progress.percentComplete,
      ));
    }
    return summaries;
  }

  @override
  Future<void> updateLastWatched(
      String courseId, String lectureId, double percent) async {
    final normalizedPercent = percent.clamp(0, 100).toDouble();
    final progressDoc = _progress.doc(lectureId);
    await progressDoc.set({
      'lessonId': lectureId,
      'courseId': courseId,
      'completed': normalizedPercent >= 100,
      'percentComplete': normalizedPercent,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
