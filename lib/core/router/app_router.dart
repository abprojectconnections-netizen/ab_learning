import '../../features/workspace/presentation/screens/my_learning_paths_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_paths.dart';
import 'role_guard.dart';
import '../widgets/error_state.dart';
import '../../shared/widgets/shell/app_shell.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/marketplace/presentation/screens/course_marketplace_screen.dart';
import '../../features/course_detail/presentation/screens/course_detail_screen.dart';
import '../../features/search/presentation/screens/search_results_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/certificate/presentation/screens/certificate_verify_screen.dart';
import '../../features/profile/presentation/screens/profile_view_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/learning/presentation/screens/video_learning_screen.dart';
import '../../features/quiz/presentation/screens/quiz_taking_screen.dart';
import '../../features/quiz/presentation/screens/quiz_editor_screen.dart';
import '../../features/jobs/presentation/screens/job_board_screen.dart';
import '../../features/quiz/presentation/screens/quiz_result_screen.dart';
import '../../features/progress/presentation/screens/progress_dashboard_screen.dart';
import '../../features/certificate/presentation/screens/my_certificates_screen.dart';
import '../../features/payment/presentation/screens/checkout_screen.dart';
import '../../features/payment/presentation/screens/order_status_screen.dart';
import '../../features/instructor_dashboard/presentation/screens/instructor_dashboard_screen.dart';
import '../../features/course_builder/presentation/screens/course_info_screen.dart';
import '../../features/course_builder/presentation/screens/curriculum_builder_screen.dart';
import '../../features/video_upload/presentation/screens/upload_video_screen.dart';
import '../../features/sales/presentation/screens/sales_dashboard_screen.dart';
import '../../features/revenue/presentation/screens/revenue_balance_screen.dart';
import '../../features/revenue/presentation/screens/payout_history_screen.dart';
import '../../features/auth/presentation/screens/role_dashboard_screen.dart';

// ใช้ prefix จริงของ URL (ไม่ใช่ pattern ที่มี :param)
const _learnerPrefixes = ['/profile', '/my-learning', '/checkout', '/orders', '/jobs'];
const _guestOnly = [
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.forgotPassword
];

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final role = ref.read(authStateProvider).role;
      final path = state.uri.path;
      String? businessPrefix;
      for (final prefix in [
        '/instructor',
        '/corporate',
        '/employer',
        '/super-admin',
        '/admin'
      ]) {
        if (path == prefix || path.startsWith('$prefix/')) {
          businessPrefix = prefix;
          break;
        }
      }
      // Public course previews remain available to guests; quiz routes require login.
      final needsLogin = businessPrefix != null ||
          path.contains('/quiz/') ||
          _learnerPrefixes.any(path.startsWith);

      if (role == UserRole.guest && needsLogin) {
        return Uri(
          path: RoutePaths.login,
          queryParameters: {'redirect': state.uri.toString()},
        ).toString();
      }
      if (role != UserRole.guest && _guestOnly.contains(path)) {
        return state.uri.queryParameters['redirect'] ?? homePathForRole(role);
      }
      if (businessPrefix != null && !_roleCanUsePrefix(role, businessPrefix)) {
        return homePathForRole(role);
      }
      return null;
    },
    errorBuilder: (context, state) =>
        const AppErrorState(message: 'ไม่พบหน้านี้'),
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Public
          GoRoute(
              path: RoutePaths.home,
              builder: (c, s) => const CourseMarketplaceScreen()),
          GoRoute(
              path: RoutePaths.explore,
              builder: (c, s) => const CourseMarketplaceScreen()),
          GoRoute(
              path: RoutePaths.courseDetail,
              builder: (c, s) =>
                  CourseDetailScreen(courseId: s.pathParameters['courseId']!)),
          GoRoute(
              path: RoutePaths.search,
              builder: (c, s) => const SearchResultsScreen()),
          GoRoute(
              path: RoutePaths.register,
              builder: (c, s) => const RegisterScreen()),
          GoRoute(
              path: RoutePaths.login, builder: (c, s) => const LoginScreen()),
          GoRoute(
              path: RoutePaths.forgotPassword,
              builder: (c, s) => const ForgotPasswordScreen()),
          GoRoute(
              path: RoutePaths.certificateVerify,
              builder: (c, s) => const CertificateVerifyScreen()),
          // Learner
          GoRoute(
              path: RoutePaths.profile,
              builder: (c, s) => const ProfileViewScreen()),
          GoRoute(
              path: RoutePaths.profileEdit,
              builder: (c, s) => const ProfileEditScreen()),
          GoRoute(
              path: RoutePaths.myCourses,
              builder: (c, s) => const ProgressDashboardScreen()),
          GoRoute(
              path: RoutePaths.progress,
              builder: (c, s) => const ProgressDashboardScreen()),
          GoRoute(
              path: RoutePaths.myLearningPaths,
              builder: (c, s) => const MyLearningPathsScreen()),
          GoRoute(
              path: RoutePaths.myCertificates,
              builder: (c, s) => const MyCertificatesScreen()),
          GoRoute(
            path: RoutePaths.videoLearning,
            builder: (c, s) => VideoLearningScreen(
                courseId: s.pathParameters['courseId']!,
                lectureId: s.pathParameters['lectureId']!),
          ),
          GoRoute(
            path: RoutePaths.quizTaking,
            builder: (c, s) => QuizTakingScreen(
                courseId: s.pathParameters['courseId']!,
                quizId: s.pathParameters['quizId']!),
          ),
          GoRoute(
            path: RoutePaths.quizResult,
            builder: (c, s) => QuizResultScreen(
                courseId: s.pathParameters['courseId']!,
                quizId: s.pathParameters['quizId']!),
          ),
          GoRoute(
              path: RoutePaths.checkout,
              builder: (c, s) =>
                  CheckoutScreen(courseId: s.pathParameters['courseId']!)),
          GoRoute(
              path: RoutePaths.orderStatus,
              builder: (c, s) =>
                  OrderStatusScreen(orderId: s.pathParameters['orderId']!)),
          // Instructor
          GoRoute(
              path: RoutePaths.instructorDashboard,
              builder: (c, s) => const InstructorDashboardScreen()),
          GoRoute(
              path: RoutePaths.courseCreate,
              builder: (c, s) => const CourseInfoScreen()),
          GoRoute(
              path: RoutePaths.curriculumBuilder,
              builder: (c, s) => CurriculumBuilderScreen(
                  courseId: s.pathParameters['courseId']!)),
          GoRoute(
            path: RoutePaths.uploadVideo,
            builder: (c, s) => UploadVideoScreen(
                courseId: s.pathParameters['courseId']!,
                lectureId: s.pathParameters['lectureId']!),
          ),
          GoRoute(
              path: RoutePaths.quizEditor,
              builder: (c, s) =>
                  QuizEditorScreen(courseId: s.pathParameters['courseId']!)),
          GoRoute(
              path: RoutePaths.jobs, builder: (c, s) => const JobBoardScreen()),
          GoRoute(
              path: RoutePaths.salesDashboard,
              builder: (c, s) => const SalesDashboardScreen()),
          GoRoute(
              path: RoutePaths.revenueBalance,
              builder: (c, s) => const RevenueBalanceScreen()),
          GoRoute(
              path: RoutePaths.payoutHistory,
              builder: (c, s) => const PayoutHistoryScreen()),
          GoRoute(
              path: RoutePaths.corporateDashboard,
              builder: (c, s) =>
                  RoleDashboardScreen(role: ref.read(authStateProvider).role)),
          GoRoute(
              path: RoutePaths.employerDashboard,
              builder: (c, s) =>
                  const RoleDashboardScreen(role: UserRole.employer)),
          GoRoute(
              path: RoutePaths.adminDashboard,
              builder: (c, s) =>
                  const RoleDashboardScreen(role: UserRole.admin)),
          GoRoute(
              path: RoutePaths.superAdminDashboard,
              builder: (c, s) =>
                  const RoleDashboardScreen(role: UserRole.superAdmin)),
        ],
      ),
    ],
  );
});

bool _roleCanUsePrefix(UserRole role, String prefix) => switch (prefix) {
      '/instructor' => role == UserRole.instructor,
      '/corporate' =>
        role == UserRole.corporateAdmin || role == UserRole.corporateManager,
      '/employer' => role == UserRole.employer,
      '/admin' => role == UserRole.admin,
      '/super-admin' => role == UserRole.superAdmin,
      _ => false,
    };
