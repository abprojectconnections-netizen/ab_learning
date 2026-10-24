import 'package:ab_learning/core/router/role_guard.dart';
import 'package:ab_learning/features/auth/presentation/screens/role_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('corporate admin can add a team member', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleDashboardScreen(role: UserRole.corporateAdmin)));
    await tester.tap(find.text('เพิ่มสมาชิก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'New teammate');
    await tester.enterText(find.byType(TextField).at(1), 'new@acme.co');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('New teammate'), findsOneWidget);
  });

  testWidgets('employer can publish a job opening', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleDashboardScreen(role: UserRole.employer)));
    await tester.tap(find.text('เพิ่มตำแหน่ง'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'QA Engineer');
    await tester.enterText(find.byType(TextField).at(1), 'Remote');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('QA Engineer'), findsOneWidget);
  });

  testWidgets('administrator can approve a submitted course', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleDashboardScreen(role: UserRole.admin)));
    await tester.tap(find.text('ตรวจสอบคอร์ส'));
    await tester.pumpAndSettle();
    final approveButton = find.byTooltip('อนุมัติคอร์ส').first;
    await tester.ensureVisible(approveButton);
    await tester.pumpAndSettle();
    await tester.tap(approveButton);
    await tester.pumpAndSettle();
    expect(find.text('อนุมัติแล้ว'), findsOneWidget);
  });
}
