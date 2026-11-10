// lib/features/marketplace/data/course_repository.dart
import '../domain/course_model.dart';

abstract class CourseRepository {
  Future<List<CourseModel>> getPublishedCourses({String? categoryId});
  Future<CourseModel?> getCourseById(String courseId);
  Future<List<CourseModel>> searchCourses(String query);
  Future<List<CategoryModel>> getCategories();
  Future<List<CourseModel>> getInstructorCourses(String instructorId);
  Future<String> createCourse({required String title, required String description, required double price, required String categoryId});
  Future<void> addSection(String courseId, String title);
  Future<void> addLecture(String courseId, String sectionId, String title);
  Future<void> publishCourse(String courseId);
}
