// test/support/mock_backend.dart
//
// In-memory repositories for widget and unit tests ONLY. Production code
// (lib/) talks to Firebase exclusively; tests inject these through
// `mockBackendOverrides`.
import 'dart:async';
import 'dart:typed_data';
import 'package:ab_learning/features/auth/data/auth_repository.dart';
import 'package:ab_learning/features/auth/domain/user_model.dart';
import 'package:ab_learning/features/auth/presentation/providers/auth_providers.dart';
import 'package:ab_learning/features/enrollment/data/enrollment_repository.dart';
import 'package:ab_learning/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:ab_learning/features/learning/data/progress_repository.dart';
import 'package:ab_learning/features/learning/domain/progress_model.dart';
import 'package:ab_learning/features/learning/presentation/providers/progress_providers.dart';
import 'package:ab_learning/features/marketplace/data/course_repository.dart';
import 'package:ab_learning/features/marketplace/domain/course_model.dart';
import 'package:ab_learning/features/marketplace/presentation/providers/course_providers.dart';
import 'package:ab_learning/features/payment/data/order_repository.dart';
import 'package:ab_learning/features/payment/domain/order_model.dart';
import 'package:ab_learning/features/payment/presentation/providers/order_providers.dart';
import 'package:ab_learning/features/profile/data/instructor_application_repository.dart';
import 'package:ab_learning/features/profile/data/profile_repository.dart';
import 'package:ab_learning/features/profile/presentation/providers/instructor_application_providers.dart';
import 'package:ab_learning/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mockBackendOverrides = <Override>[
  authRepositoryProvider.overrideWith((ref) => MockAuthRepository()),
  courseRepositoryProvider.overrideWith((ref) => MockCourseRepository()),
  orderRepositoryProvider.overrideWith((ref) => MockOrderRepository()),
  progressRepositoryProvider.overrideWith((ref) => MockProgressRepository()),
  enrollmentRepositoryProvider.overrideWith((ref) => MockEnrollmentRepository()),
  profileRepositoryProvider.overrideWith((ref) => MockProfileRepository()),
  instructorApplicationRepositoryProvider
      .overrideWith((ref) => MockInstructorApplicationRepository()),
];

/// Local demo identities. Production authorization must come from Firebase
/// custom claims, never from the email address.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  AppUser _fakeUser(String email, {bool forceLearner = false}) {
    final normalized = email.trim().toLowerCase();
    final role = forceLearner ? UserRoleType.learner : _demoRole(normalized);
    return AppUser(
      uid: role == UserRoleType.instructor
          ? 'instructor-1'
          : 'demo-${role.name}',
      email: normalized,
      displayName: normalized.split('@').first,
      role: role,
    );
  }

  UserRoleType _demoRole(String email) {
    if (email.contains('superadmin') || email.contains('super_admin')) {
      return UserRoleType.superAdmin;
    }
    if (email == 'krit@ablearning.com' || email.contains('instructor')) {
      return UserRoleType.instructor;
    }
    if (email == 'manager@ablearning.com' || email.contains('manager')) {
      return UserRoleType.corporateManager;
    }
    if (email == 'corp@ablearning.com' || email.contains('corp')) {
      return UserRoleType.corporateAdmin;
    }
    if (email == 'employer@ablearning.com' || email.contains('employer')) {
      return UserRoleType.employer;
    }
    if (email == 'admin@ablearning.com' || email.contains('admin')) {
      return UserRoleType.admin;
    }
    return UserRoleType.learner;
  }

  void _validate(String email, String password) {
    if (!email.contains('@') || password.length < 6) {
      throw Exception(
          'Enter a valid email and a password of at least 6 characters.');
    }
  }

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _validate(email.trim(), password);
    _current = _fakeUser(email);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<AppUser> register(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _validate(email.trim(), password);
    _current = _fakeUser(email, forceLearner: true);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
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

class MockOrderRepository implements OrderRepository {
  @override
  Future<String> startCheckout(String orderId, String returnUrl) async =>
      'https://checkout.example.test/$orderId';

  final _orders = <String, OrderModel>{};

  @override
  Future<String> createOrder(String courseId, double amount) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final id = 'order-${DateTime.now().millisecondsSinceEpoch}';
    _orders[id] = OrderModel(id: id, courseId: courseId, courseTitle: 'คอร์สที่เลือกซื้อ', amount: amount, status: OrderStatus.pending, createdAt: DateTime.now());
    return id;
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _orders[orderId] ?? OrderModel(id: orderId, courseId: '-', courseTitle: '-', amount: 0, status: OrderStatus.pending, createdAt: DateTime.now());
  }

  @override
  Future<void> confirmMockPayment(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final existing = _orders[orderId];
    if (existing != null) {
      _orders[orderId] = OrderModel(id: existing.id, courseId: existing.courseId, courseTitle: existing.courseTitle, amount: existing.amount, status: OrderStatus.paid, createdAt: existing.createdAt);
    }
  }
}

class MockProgressRepository implements ProgressRepository {
  final _completed = <String, Set<String>>{};
  final _last = <String, String>{};

  @override
  Future<ProgressModel> getProgress(String courseId) async {
    final done = _completed[courseId] ?? <String>{};
    return ProgressModel(
      courseId: courseId,
      completedLectureIds: done.toList(),
      lastWatchedLectureId: _last[courseId],
      percentComplete: done.isEmpty ? 0 : 100,
    );
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
    _last[courseId] = lectureId;
    if (percent >= 100) {
      (_completed[courseId] ??= <String>{}).add(lectureId);
    }
  }
}

class MockEnrollmentRepository implements EnrollmentRepository {
  final Set<String> _ids = {'course-0'};
  final _controller = StreamController<Set<String>>.broadcast();

  @override
  Stream<Set<String>> watchEnrolledCourseIds() async* {
    yield Set.of(_ids);
    yield* _controller.stream;
  }

  @override
  Future<void> enrollFreeCourse(String courseId) async {
    _ids.add(courseId);
    _controller.add(Set.of(_ids));
  }
}

class MockProfileRepository implements ProfileRepository {
  bool deleted = false;
  String? deletionBlockedReason;

  @override
  Future<void> deleteMyAccount() async {
    final reason = deletionBlockedReason;
    if (reason != null) throw AccountDeletionBlocked(reason);
    deleted = true;
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, String contentType) async =>
      'https://example.test/avatar.png';

  UserProfile _profile = const UserProfile(
    uid: 'mock-user',
    email: 'learner@test.com',
    displayName: 'ผู้ใช้งานระบบ AB',
  );

  @override
  Future<UserProfile> getMyProfile() async => _profile;

  @override
  Future<void> updateMyProfile({
    required String displayName,
    String? bio,
    String? photoUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _profile = UserProfile(
      uid: _profile.uid,
      email: _profile.email,
      displayName: displayName,
      bio: bio ?? _profile.bio,
      photoUrl: photoUrl ?? _profile.photoUrl,
    );
  }
}

class MockInstructorApplicationRepository
    implements InstructorApplicationRepository {
  InstructorApplicationStatus status = InstructorApplicationStatus.none;
  String? lastExperience;

  @override
  Future<InstructorApplicationStatus> myStatus() async => status;

  @override
  Future<void> apply({
    required String displayName,
    required String experience,
  }) async {
    lastExperience = experience;
    status = InstructorApplicationStatus.pending;
  }
}
