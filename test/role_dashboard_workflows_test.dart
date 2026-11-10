import 'package:ab_learning/core/router/role_guard.dart';
import 'package:ab_learning/features/auth/presentation/screens/role_dashboard_screen.dart';
import 'package:ab_learning/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_workspace.dart';

Widget _app(UserRole role, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: RoleDashboardScreen(role: role),
    ),
  );
}

/// Find a widget, scroll it into view, and tap it.
Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder,
) async {
  expect(finder, findsOneWidget);

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();

  expect(
    finder.hitTestable(),
    findsOneWidget,
    reason: 'Widget must be visible and receive pointer events.',
  );

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Role dashboard workflows', () {
    testWidgets(
      'corporate admin adds a member through the repository',
      (tester) async {
        await tester.pumpWidget(
          _app(UserRole.corporateAdmin, [
            orgRepositoryProvider.overrideWithValue(
              FakeOrgRepository(),
            ),
          ]),
        );

        await tester.pumpAndSettle();

        expect(find.text('Acme Admin'), findsOneWidget);

        await _tapVisible(
          tester,
          find.text('เพิ่มสมาชิก'),
        );

        expect(find.byType(TextField), findsWidgets);

        await tester.enterText(
          find.byType(TextField).at(0),
          'newhire@acme.co',
        );

        await _tapVisible(
          tester,
          find.text('บันทึก'),
        );

        expect(find.text('newhire'), findsOneWidget);
      },
    );

    testWidgets(
      'employer publishes a job opening through the repository',
      (tester) async {
        await tester.pumpWidget(
          _app(UserRole.employer, [
            recruitmentRepositoryProvider.overrideWithValue(
              FakeRecruitmentRepository(),
            ),
          ]),
        );

        await tester.pumpAndSettle();

        expect(find.text('ยังไม่มีรายการ'), findsOneWidget);

        await _tapVisible(
          tester,
          find.text('เพิ่มตำแหน่ง'),
        );

        expect(find.byType(TextField), findsWidgets);

        await tester.enterText(
          find.byType(TextField).at(0),
          'QA Engineer',
        );

        await tester.enterText(
          find.byType(TextField).at(1),
          'Remote',
        );

        await _tapVisible(
          tester,
          find.text('บันทึก'),
        );

        expect(find.text('QA Engineer'), findsOneWidget);
      },
    );

    testWidgets(
      'administrator approves a submitted course',
      (tester) async {
        final admin = FakeAdminRepository();

        await tester.pumpWidget(
          _app(UserRole.admin, [
            adminRepositoryProvider.overrideWithValue(admin),
          ]),
        );

        await tester.pumpAndSettle();

        // Open course review screen.
        await _tapVisible(
          tester,
          find.text('ตรวจสอบคอร์ส'),
        );

        expect(
          find.text('Flutter พื้นฐาน'),
          findsOneWidget,
        );

        // Locate the actual approval action.
        final approveButton = find.byTooltip('อนุมัติคอร์ส');

        // Scroll before tapping to avoid off-screen hit-test warnings.
        await tester.ensureVisible(approveButton);
        await tester.pumpAndSettle();

        expect(
          approveButton.hitTestable(),
          findsOneWidget,
          reason: 'Approve button must be visible before tapping.',
        );

        await tester.tap(approveButton);
        await tester.pumpAndSettle();

        // Verify repository received the approval status.
        expect(
          admin.lastReview,
          'published',
          reason: 'Administrator approval must publish the course.',
        );

        // Verify the reviewed course is removed from pending list.
        expect(
          find.text('Flutter พื้นฐาน'),
          findsNothing,
        );
      },
    );
  });
}
