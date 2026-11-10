// lib/features/learning/data/progress_repository.dart
import '../domain/progress_model.dart';

abstract class ProgressRepository {
  Future<ProgressModel> getProgress(String courseId);
  Future<List<EnrolledCourseSummary>> getMyEnrolledCourses();
  Future<void> updateLastWatched(String courseId, String lectureId, double percent);
}
