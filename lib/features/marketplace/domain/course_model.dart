// lib/features/marketplace/domain/course_model.dart

class CategoryModel {
  final String id;
  final String name;
  const CategoryModel({required this.id, required this.name});
}

class LectureModel {
  final String id;
  final String title;
  final int durationSeconds;
  final int order;
  final bool isPreview;
  final String? videoRef; // null = ยังไม่อัปโหลด
  const LectureModel({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.order,
    required this.isPreview,
    this.videoRef,
  });
}

class SectionModel {
  final String id;
  final String title;
  final int order;
  final List<LectureModel> lectures;
  const SectionModel({
    required this.id,
    required this.title,
    required this.order,
    required this.lectures,
  });
}

class ReviewModel {
  final String learnerName;
  final double rating;
  final String comment;
  const ReviewModel(
      {required this.learnerName, required this.rating, required this.comment});
}

enum CourseStatus { draft, pendingReview, published, rejected, archived }

class CourseModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final String categoryId;
  final String instructorId;
  final String instructorName;
  final String thumbnailUrl;
  final String? previewVideoUrl;
  final CourseStatus status;
  final double avgRating;
  final int totalStudents;
  final int totalReviews;
  final List<SectionModel> sections;
  final List<ReviewModel> reviews;

  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.categoryId,
    required this.instructorId,
    required this.instructorName,
    required this.thumbnailUrl,
    this.previewVideoUrl,
    required this.status,
    this.avgRating = 0,
    this.totalStudents = 0,
    this.totalReviews = 0,
    this.sections = const [],
    this.reviews = const [],
  });
}
