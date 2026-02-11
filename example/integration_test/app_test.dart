import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testwire_flutter/testwire_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testwire/testwire.dart';
import 'package:testwire_example/main.dart' as app;

class FeedbackTest extends TestwireTest {
  FeedbackTest()
    : super(
        'Submit feedback with valid data',
        setUp: (tester) async {
          app.main();
          await tester.pumpAndSettle();
        },
      );

  @override
  Future<void> body(WidgetTester tester) async {
    await step(
      description: 'Enter name',
      context: 'Type "Alex" into the name field.',
      action: () async {
        await tester.enterText(find.byKey(const Key('name_field')), 'Alex');
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Tap 4-star rating',
      context: 'Tap the 4th star to set rating to 4.',
      action: () async {
        await tester.tap(find.byKey(const Key('star_4')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Enter comment',
      context: 'Type "Great app!" into the comment field.',
      action: () async {
        await tester.enterText(
          find.byKey(const Key('comment_field')),
          'Great app!',
        );
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Tap submit button',
      context: 'Tap the Submit button to send the form.',
      action: () async {
        await tester.tap(find.byKey(const Key('submit_button')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Verify success screen',
      context:
          'Check that "Thank you for your feedback!" and "4 stars from Alex" '
          'are displayed.',
      action: () async {
        expect(find.text('Thank you for your feedback!'), findsOneWidget);
        expect(find.text('4 stars from Alex'), findsOneWidget);
      },
    );

    await step(
      description: 'Tap Send Another',
      context: 'Tap the "Send Another" button to return to the form.',
      action: () async {
        await tester.tap(find.byKey(const Key('reset_button')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Enter second name',
      context: 'Type "Bob" into the name field.',
      action: () async {
        await tester.enterText(find.byKey(const Key('name_field')), 'Bob');
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Tap 5-star rating',
      context: 'Tap the 5th star to set rating to 5.',
      action: () async {
        await tester.tap(find.byKey(const Key('star_5')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Submit second feedback',
      context: 'Tap the Submit button.',
      action: () async {
        await tester.tap(find.byKey(const Key('submit_button')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Verify second success',
      context: 'Check that "5 stars from Bob" is displayed.',
      action: () async {
        expect(find.text('5 stars from Bob'), findsOneWidget);
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerTestwireExtensions();
  FeedbackTest().run();
}
