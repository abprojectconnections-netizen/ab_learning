import 'package:ab_learning/features/profile/data/instructor_application_repository.dart';
import 'package:ab_learning/features/profile/presentation/providers/instructor_application_providers.dart';
import 'package:ab_learning/features/profile/presentation/widgets/instructor_application_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_backend.dart';

Widget _card(MockInstructorApplicationRepository repo) => ProviderScope(
      overrides: [
        instructorApplicationRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InstructorApplicationCard(displayName: 'Learner'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('learner submits an instructor application', (tester) async {
    final repo = MockInstructorApplicationRepository();
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();
    expect(find.text('ส่งใบสมัคร'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'สอนการออกแบบ UI มากว่า 5 ปี และมีผลงานจริง');
    await tester.tap(find.text('ส่งใบสมัคร'));
    await tester.pumpAndSettle();

    expect(repo.lastExperience, contains('สอนการออกแบบ UI'));
    expect(find.textContaining('อยู่ระหว่างการตรวจสอบ'), findsOneWidget);
  });

  testWidgets('shows review status when already applied', (tester) async {
    final repo = MockInstructorApplicationRepository()
      ..status = InstructorApplicationStatus.rejected;
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('ไม่ได้รับการอนุมัติ'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
