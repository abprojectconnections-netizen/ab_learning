import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/certificate/domain/certificate_model.dart';

class AppState {
  final Set<String> enrolledCourseIds;
  final Map<String, double> courseProgress; // courseId -> percent (0-100)
  final Map<String, bool> quizPassed;       // courseId -> passed
  final List<CertificateModel> certificates;

  const AppState({
    this.enrolledCourseIds = const {'course-0'}, // ให้คอร์สแรกเรียนฟรีเป็นค่าเริ่มต้นเพื่อเทสต์ง่าย
    this.courseProgress = const {},
    this.quizPassed = const {},
    this.certificates = const [],
  });

  AppState copyWith({
    Set<String>? enrolledCourseIds,
    Map<String, double>? courseProgress,
    Map<String, bool>? quizPassed,
    List<CertificateModel>? certificates,
  }) {
    return AppState(
      enrolledCourseIds: enrolledCourseIds ?? this.enrolledCourseIds,
      courseProgress: courseProgress ?? this.courseProgress,
      quizPassed: quizPassed ?? this.quizPassed,
      certificates: certificates ?? this.certificates,
    );
  }
}

class AppStoreNotifier extends StateNotifier<AppState> {
  AppStoreNotifier() : super(const AppState());

  // 1. ซื้อคอร์สสำเร็จ -> ปลดล็อกสิทธิ์เข้าเรียน
  void enrollCourse(String courseId) {
    if (state.enrolledCourseIds.contains(courseId)) return;
    state = state.copyWith(
      enrolledCourseIds: {...state.enrolledCourseIds, courseId},
      courseProgress: {...state.courseProgress, courseId: 0.0},
    );
  }

  // 2. อัปเดต Progress การเรียน
  void updateProgress(String courseId, double percent) {
    final newProgress = {...state.courseProgress, courseId: percent};
    state = state.copyWith(courseProgress: newProgress);

    // ตรวจสอบเงื่อนไขออก Certificate อัตโนมัติ (ครบ 100% และ Quiz ต้องผ่านแล้ว)
    if (percent >= 100.0 && (state.quizPassed[courseId] ?? false)) {
      _issueCertificate(courseId);
    }
  }

  // 3. บันทึกผลสอบ Quiz
  bool submitQuizAndCheck(String courseId, int scorePercent) {
    final passed = scorePercent >= 70; // เกณฑ์ผ่าน 70%
    final newQuizPassed = {...state.quizPassed, courseId: passed};
    state = state.copyWith(quizPassed: newQuizPassed);

    // ถ้าเรียนครบ 100 อยู่แล้วแล้วมาสอบผ่านทีหลัง -> ออก Certificate ทันที
    if (passed && (state.courseProgress[courseId] ?? 0.0) >= 100.0) {
      _issueCertificate(courseId);
    }
    return passed;
  }

  // 4. ออก Certificate
  void _issueCertificate(String courseId) {
    // ป้องกันการออกซ้ำ
    if (state.certificates.any((c) => c.id == 'cert-$courseId')) return;

    final newCert = CertificateModel(
      id: 'cert-$courseId',
      courseTitle: 'คอร์สเรียนรหัส $courseId',
      learnerName: 'ผู้ใช้งานระบบ',
      issuedAt: DateTime.now(),
      verificationCode: 'AB-${courseId.toUpperCase()}-${DateTime.now().year}',
    );

    state = state.copyWith(certificates: [...state.certificates, newCert]);
  }
}

final appStoreProvider = StateNotifierProvider<AppStoreNotifier, AppState>((ref) {
  return AppStoreNotifier();
});