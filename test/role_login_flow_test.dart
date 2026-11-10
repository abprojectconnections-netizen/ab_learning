import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_backend.dart';
import 'package:ab_learning/core/router/app_router.dart';
import 'package:ab_learning/features/auth/presentation/screens/role_dashboard_screen.dart';
import 'package:ab_learning/features/instructor_dashboard/presentation/screens/instructor_dashboard_screen.dart';
import 'package:ab_learning/features/marketplace/presentation/screens/course_marketplace_screen.dart';

void main() {
  const accounts = <({String email, String? dashboard})>[
    (email: 'learner@ablearning.com', dashboard: null),
    (email: 'krit@ablearning.com', dashboard: 'instructor'),
    (email: 'corp@ablearning.com', dashboard: 'Corporate Admin Dashboard'),
    (email: 'manager@ablearning.com', dashboard: 'Corporate Manager Dashboard'),
    (email: 'employer@ablearning.com', dashboard: 'Employer Dashboard'),
    (email: 'admin@ablearning.com', dashboard: 'Administration Dashboard'),
    (email: 'superadmin@ablearning.com', dashboard: 'Super Admin Dashboard'),
  ];

  for (final account in accounts) {
    testWidgets('login routes ${account.email} to the correct role',
        (tester) async {
      final container = ProviderContainer(
        overrides: mockBackendOverrides,
      );
      final router = container.read(appRouterProvider)..go('/login');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), account.email);
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      if (account.dashboard == null) {
        expect(find.byType(CourseMarketplaceScreen), findsOneWidget);
      } else if (account.dashboard == 'instructor') {
        expect(find.byType(InstructorDashboardScreen), findsOneWidget);
      } else {
        expect(find.text(account.dashboard!), findsOneWidget);
        expect(find.byType(RoleDashboardScreen), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
    });
  }
}
