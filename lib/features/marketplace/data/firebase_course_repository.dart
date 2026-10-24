import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/course_model.dart';
import 'course_repository.dart';

class FirebaseCourseRepository implements CourseRepository {
  FirebaseCourseRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection('courses');

  @override
  Future<List<CourseModel>> getPublishedCourses({String? categoryId}) async {
    Query<Map<String, dynamic>> query =
        _courses.where('status', isEqualTo: 'published');
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    final result = await query.get();
    return result.docs.map(_fromDocument).toList();
  }

  @override
  Future<CourseModel?> getCourseById(String courseId) async {
    final snapshot = await _courses.doc(courseId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    final ref = _courses.doc(courseId);
    final sectionDocs = await ref.collection('sections').orderBy('order').get();
    final user = _auth.currentUser;
    var canReadAllLessons = user?.uid == data['instructorId'];
    if (user != null && !canReadAllLessons) {
      final token = await user.getIdTokenResult();
      canReadAllLessons =
          token.claims?['role'] == 'admin' || token.claims?['role'] == 'super_admin';
      if (!canReadAllLessons) {
        final enrollment = await _firestore
            .collection('enrollments')
            .doc('${user.uid}_$courseId')
            .get();
        canReadAllLessons = enrollment.data()?['status'] == 'active';
      }
    }
    Query<Map<String, dynamic>> lessons = ref.collection('lessons');
    if (!canReadAllLessons) {
      lessons = lessons.where('isPreview', isEqualTo: true);
    }
    final lessonDocs = await lessons.orderBy('order').get();
    final sections = sectionDocs.docs.map((section) {
      final sectionLessons = lessonDocs.docs
          .where((lesson) => lesson.data()['sectionId'] == section.id)
          .map((lesson) {
        final value = lesson.data();
        return LectureModel(
          id: lesson.id,
          title: value['title'] as String? ?? '',
          durationSeconds: (value['durationSeconds'] as num?)?.toInt() ?? 0,
          order: (value['order'] as num?)?.toInt() ?? 0,
          isPreview: value['isPreview'] as bool? ?? false,
          videoRef: value['videoRef'] as String?,
        );
      }).toList();
      return SectionModel(
        id: section.id,
        title: section.data()['title'] as String? ?? '',
        order: (section.data()['order'] as num?)?.toInt() ?? 0,
        lectures: sectionLessons,
      );
    }).toList();
    return _fromData(snapshot.id, data, sections: sections);
  }

  @override
  Future<List<CourseModel>> searchCourses(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final published = await getPublishedCourses();
    return published
        .where((course) => course.title.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final result = await _firestore.collection('categories').get();
    return result.docs
        .map((doc) => CategoryModel(
              id: doc.id,
              name: (doc.data()['name'] as String?) ?? '',
            ))
        .where((category) => category.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    final result =
        await _courses.where('instructorId', isEqualTo: instructorId).get();
    return result.docs.map(_fromDocument).toList();
  }

  @override
  Future<String> createCourse({
    required String title,
    required String description,
    required double price,
    required String categoryId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in is required to create a course.');
    }
    final ref = _courses.doc();
    await ref.set({
      'title': title.trim(),
      'description': description.trim(),
      'price': price,
      'categoryId': categoryId,
      'instructorId': user.uid,
      'instructorName': user.displayName ?? 'Instructor',
      'thumbnailUrl': '',
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> addSection(String courseId, String title) async {
    final courseRef = _courses.doc(courseId);
    final sectionRef = courseRef.collection('sections').doc();
    final currentSections = await courseRef.collection('sections').get();
    await sectionRef.set({
      'title': title.trim(),
      'order': currentSections.size + 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addLecture(
      String courseId, String sectionId, String title) async {
    final courseRef = _courses.doc(courseId);
    final section = await courseRef.collection('sections').doc(sectionId).get();
    if (!section.exists) throw StateError('Course section does not exist.');
    final existingLectures = await courseRef
        .collection('lessons')
        .where('sectionId', isEqualTo: sectionId)
        .get();
    await courseRef.collection('lessons').add({
        'sectionId': sectionId,
        'title': title.trim(),
        'durationSeconds': 0,
        'order': existingLectures.size + 1,
        'isPreview': false,
        'videoRef': null,
      });
  }

  @override
  Future<void> publishCourse(String courseId) async {
    await _courses.doc(courseId).update({
      'status': 'pending_review',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CourseModel _fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document) {
    return _fromData(document.id, document.data());
  }

  CourseModel _fromData(String id, Map<String, dynamic> data,
      {List<SectionModel> sections = const []}) {
    final rawStatus = data['status'] as String? ?? 'draft';
    final status = switch (rawStatus) {
      'published' => CourseStatus.published,
      'pending_review' => CourseStatus.pendingReview,
      'rejected' => CourseStatus.rejected,
      'archived' => CourseStatus.archived,
      _ => CourseStatus.draft,
    };
    return CourseModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      categoryId: data['categoryId'] as String? ?? '',
      instructorId: data['instructorId'] as String? ?? '',
      instructorName: data['instructorName'] as String? ?? 'Instructor',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      status: status,
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0,
      totalStudents: (data['totalStudents'] as num?)?.toInt() ?? 0,
      totalReviews: (data['totalReviews'] as num?)?.toInt() ?? 0,
      sections: sections,
    );
  }

}
