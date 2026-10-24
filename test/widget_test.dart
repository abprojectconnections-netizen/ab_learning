import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ab_learning/app.dart';
import 'package:ab_learning/core/config/app_config.dart';

void main() {
  testWidgets('AB Learning app renders successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.dev),
        ],
        child: const ABLearningApp(),
      ),
    );

    // Render the initial frame of the application.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.byType(ABLearningApp), findsOneWidget);
  });
}
