// lib/features/learning/data/progress_repository.dart
import '../domain/progress_model.dart';

abstract class ProgressRepository {
  Future<ProgressModel> getProgress(String courseId);
  Future<List<EnrolledCourseSummary>> getMyEnrolledCourses();
  Future<void> updateLastWatched(String courseId, String lectureId, double percent);
}

class MockProgressRepository implements ProgressRepository {
  @override
  Future<ProgressModel> getProgress(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return ProgressModel(courseId: courseId, completedLectureIds: const ['l1'], lastWatchedLectureId: 'l2', percentComplete: 45);
  }

  @override
  Future<List<EnrolledCourseSummary>> getMyEnrolledCourses() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const EnrolledCourseSummary(courseId: 'course-0', title: 'คอร์สตัวอย่างที่ 1', thumbnailUrl: 'https://picsum.photos/seed/course0/400/225', percentComplete: 70),
      const EnrolledCourseSummary(courseId: 'course-1', title: 'คอร์สตัวอย่างที่ 2', thumbnailUrl: 'https://picsum.photos/seed/course1/400/225', percentComplete: 100),
    ];
  }

  @override
  Future<void> updateLastWatched(String courseId, String lectureId, double percent) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // TODO: เขียนลง progress/{uid}/courses/{courseId} จริงตอนเชื่อม Firebase
  }
}