class RoutePaths {
  static const home = '/';
  static const explore = '/explore';
  static const courseDetail = '/courses/:courseId';
  static const search = '/search';
  static const register = '/register';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const certificateVerify = '/verify';

  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const myCourses = '/my-learning/courses';
  static const videoLearning = '/learn/:courseId/:lectureId';
  static const quizTaking = '/learn/:courseId/quiz/:quizId';
  static const quizResult = '/learn/:courseId/quiz/:quizId/result';
  static const progress = '/my-learning/progress';
  static const myCertificates = '/my-learning/certificates';
  static const myLearningPaths = '/my-learning/paths';
  static const checkout = '/checkout/:courseId';
  static const orderStatus = '/orders/:orderId';

  static const instructorDashboard = '/instructor';
  static const courseCreate = '/instructor/courses/new';
  static const curriculumBuilder = '/instructor/courses/:courseId/curriculum';
  static const uploadVideo =
      '/instructor/courses/:courseId/lectures/:lectureId/upload';
  static const quizEditor = '/instructor/courses/:courseId/quiz';
  static const jobs = '/jobs';
  static const salesDashboard = '/instructor/sales';
  static const revenueBalance = '/instructor/revenue';
  static const payoutHistory = '/instructor/revenue/history';

  static const corporateDashboard = '/corporate';
  static const employerDashboard = '/employer';
  static const adminDashboard = '/admin';
  static const superAdminDashboard = '/super-admin';
}
