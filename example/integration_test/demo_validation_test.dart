// =============================================================================
// DEMO 3 — Validation Flow
// =============================================================================
//
// PURPOSE:
//   This test verifies that form validation works correctly — submitting
//   without required fields shows error messages, and filling them in
//   allows successful submission.
//
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testwire_flutter/testwire_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testwire/testwire.dart';
import 'package:testwire_example/main.dart' as app;

class ValidationDemo extends TestwireTest {
  ValidationDemo()
    : super(
        'Form validation — errors appear and clear correctly',
        setUp: (tester) async {
          app.main();
          await tester.pumpAndSettle();
        },
      );

  @override
  Future<void> body(WidgetTester tester) async {
    await step(
      description: 'Navigate to Leave Review',
      context: 'Tap the "Leave Review" tile on the home screen.',
      action: () async {
        await tester.tap(find.byKey(const Key('leave_review_tile')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Submit empty form',
      context:
          'Tap Submit without filling any fields — expect validation errors.',
      action: () async {
        await tester.tap(find.byKey(const Key('submit_button')));
        await tester.pumpAndSettle();
        expect(find.text('Name is required'), findsOneWidget);
        expect(find.text('Please select a rating'), findsOneWidget);
      },
    );

    await step(
      description: 'Enter name and submit again',
      context:
          'Fill in name, tap Submit — name error gone, rating error remains.',
      action: () async {
        await tester.enterText(find.byKey(const Key('name_field')), 'Alex');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('submit_button')));
        await tester.pumpAndSettle();
        expect(find.text('Name is required'), findsNothing);
        expect(find.text('Please select a rating'), findsOneWidget);
      },
    );

    await step(
      description: 'Tap 4-star rating',
      context: 'Tap the 4th star — rating error should disappear.',
      action: () async {
        await tester.tap(find.byKey(const Key('star_4')));
        await tester.pumpAndSettle();
        expect(find.text('Please select a rating'), findsNothing);
      },
    );

    await step(
      description: 'Tap submit button',
      context: 'Tap Submit — form is now valid, should navigate to success.',
      action: () async {
        await tester.tap(find.byKey(const Key('submit_button')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Verify success screen',
      context: 'Check that success message and rating summary are displayed.',
      action: () async {
        expect(find.text('Thank you for your feedback!'), findsOneWidget);
        expect(find.text('4 stars from Alex'), findsOneWidget);
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerTestwireExtensions();
  ValidationDemo().run();
}
