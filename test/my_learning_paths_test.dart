import 'package:ab_learning/features/workspace/domain/workspace_models.dart';
import 'package:ab_learning/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:ab_learning/features/workspace/presentation/screens/my_learning_paths_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_workspace.dart';
import 'support/mock_backend.dart';

Widget _screen(FakeOrgRepository repo) => ProviderScope(
      overrides: [
        ...mockBackendOverrides,
        orgRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: MyLearningPathsScreen()),
    );

void main() {
  testWidgets('member sees active organization paths', (tester) async {
    final repo = FakeOrgRepository()
      ..addActivePath(const LearningPath(
          id: 'p1',
          orgId: 'org1',
          title: 'Onboarding พนักงานใหม่',
          description: 'เริ่มต้นทำงาน',
          status: 'active',
          courseIds: []));
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding พนักงานใหม่'), findsOneWidget);
    expect(find.text('ยังไม่ได้กำหนดคอร์สในแผนนี้'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no paths', (tester) async {
    await tester.pumpWidget(_screen(FakeOrgRepository()));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีแผนการเรียนจากองค์กรของคุณ'), findsOneWidget);
  });
}
