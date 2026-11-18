import 'package:ab_learning/core/router/role_guard.dart';
import 'package:ab_learning/features/auth/presentation/screens/role_dashboard_screen.dart';
import 'package:ab_learning/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_workspace.dart';

Widget _app(UserRole role, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: RoleDashboardScreen(role: role)),
    );

void main() {
  testWidgets('corporate admin adds a member through the repository', (tester) async {
    await tester.pumpWidget(_app(UserRole.corporateAdmin, [
      orgRepositoryProvider.overrideWithValue(FakeOrgRepository()),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Acme Admin'), findsOneWidget);

    await tester.tap(find.text('เพิ่มสมาชิก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'newhire@acme.co');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('newhire'), findsOneWidget);
  });

  testWidgets('employer publishes a job opening through the repository', (tester) async {
    await tester.pumpWidget(_app(UserRole.employer, [
      recruitmentRepositoryProvider.overrideWithValue(FakeRecruitmentRepository()),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีรายการ'), findsOneWidget);

    await tester.tap(find.text('เพิ่มตำแหน่ง'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'QA Engineer');
    await tester.enterText(find.byType(TextField).at(1), 'Remote');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('QA Engineer'), findsOneWidget);
  });

  testWidgets('administrator approves a submitted course', (tester) async {
    final admin = FakeAdminRepository();
    await tester.pumpWidget(_app(UserRole.admin, [
      adminRepositoryProvider.overrideWithValue(admin),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตรวจสอบคอร์ส'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter พื้นฐาน'), findsOneWidget);

    final approve = find.byTooltip('อนุมัติคอร์ส');
    await tester.ensureVisible(approve); // the button is below the 600px test viewport
    await tester.pumpAndSettle();
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(admin.lastReview, 'published');
    expect(find.text('Flutter พื้นฐาน'), findsNothing);
  });
}
