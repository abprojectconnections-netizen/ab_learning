// lib/features/learning/domain/progress_model.dart
class ProgressModel {
  final String courseId;
  final List<String> completedLectureIds;
  final String? lastWatchedLectureId;
  final double percentComplete; // 0-100

  const ProgressModel({
    required this.courseId,
    this.completedLectureIds = const [],
    this.lastWatchedLectureId,
    this.percentComplete = 0,
  });
}

class EnrolledCourseSummary {
  final String courseId;
  final String title;
  final String thumbnailUrl;
  final double percentComplete;
  const EnrolledCourseSummary({
    required this.courseId,
    required this.title,
    required this.thumbnailUrl,
    required this.percentComplete,
  });
}