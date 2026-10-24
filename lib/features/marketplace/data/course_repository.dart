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

class MockCourseRepository implements CourseRepository {
  static final _mockCourses = List.generate(8, (i) => CourseModel(
        id: 'course-$i',
        title: 'คอร์สตัวอย่างที่ ${i + 1}',
        description: 'คำอธิบายคอร์สตัวอย่างสำหรับทดสอบ UI',
        price: 990 + (i * 100),
        originalPrice: 1990 + (i * 100),
        categoryId: i % 2 == 0 ? 'cat-it' : 'cat-design',
        instructorId: 'instructor-1',
        instructorName: 'ครูสมชาย',
        thumbnailUrl: 'https://picsum.photos/seed/course$i/400/225',
        status: CourseStatus.published,
        avgRating: 4.2 + (i % 3) * 0.2,
        totalStudents: 120 + i * 30,
        totalReviews: 20 + i,
        sections: [
          const SectionModel(id: 's1', title: 'บทนำ', order: 1, lectures: [
            LectureModel(id: 'l1', title: 'แนะนำคอร์ส', durationSeconds: 300, order: 1, isPreview: true, videoRef: 'mock-video-1'),
            LectureModel(id: 'l2', title: 'เริ่มต้นใช้งาน', durationSeconds: 600, order: 2, isPreview: false, videoRef: 'mock-video-2'),
          ]),
        ],
        reviews: const [
          ReviewModel(learnerName: 'นักเรียน A', rating: 5, comment: 'สอนดีมากครับ'),
        ],
      ));

  @override
  Future<List<CourseModel>> getPublishedCourses({String? categoryId}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (categoryId == null) return _mockCourses;
    return _mockCourses.where((c) => c.categoryId == categoryId).toList();
  }

  @override
  Future<CourseModel?> getCourseById(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockCourses.firstWhere((c) => c.id == courseId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CourseModel>> searchCourses(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (query.isEmpty) return [];
    return _mockCourses.where((c) => c.title.contains(query)).toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    return const [
      CategoryModel(id: 'cat-it', name: 'IT & ซอฟต์แวร์'),
      CategoryModel(id: 'cat-design', name: 'ออกแบบ'),
      CategoryModel(id: 'cat-marketing', name: 'การตลาด'),
    ];
  }

  @override
  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockCourses.where((c) => c.instructorId == instructorId).toList();
  }

  @override
  Future<String> createCourse({required String title, required String description, required double price, required String categoryId}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'course-new-${DateTime.now().millisecondsSinceEpoch}'; // TODO: เรียก Firestore จริงภายหลัง
  }

  @override
  Future<void> addSection(String courseId, String title) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> addLecture(String courseId, String sectionId, String title) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> publishCourse(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}