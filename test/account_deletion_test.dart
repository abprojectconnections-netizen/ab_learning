import 'package:ab_learning/features/profile/presentation/providers/profile_provider.dart';
import 'package:ab_learning/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_backend.dart';

Widget _screen(MockProfileRepository repo) => ProviderScope(
      overrides: [
        ...mockBackendOverrides,
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: ProfileEditScreen()),
    );

Future<void> _openDialog(WidgetTester tester) async {
  final button = find.text('ลบบัญชี');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('account is deleted only after typing DELETE', (tester) async {
    final repo = MockProfileRepository();
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.enterText(find.byType(TextField).last, 'nope');
    await tester.tap(find.text('ลบบัญชี').last);
    await tester.pumpAndSettle();
    expect(repo.deleted, isFalse);

    await _openDialog(tester);
    await tester.enterText(find.byType(TextField).last, 'DELETE');
    await tester.tap(find.text('ลบบัญชี').last);
    await tester.pumpAndSettle();
    expect(repo.deleted, isTrue);
  });

  testWidgets('shows the reason when deletion is blocked', (tester) async {
    final repo = MockProfileRepository()
      ..deletionBlockedReason = 'Archive or transfer your courses first.';
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.enterText(find.byType(TextField).last, 'DELETE');
    await tester.tap(find.text('ลบบัญชี').last);
    await tester.pumpAndSettle();

    expect(repo.deleted, isFalse);
    expect(find.text('Archive or transfer your courses first.'), findsOneWidget);
  });
}
