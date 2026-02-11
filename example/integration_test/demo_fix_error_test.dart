// =============================================================================
// DEMO 1 — Fix Error Flow
// =============================================================================
//
// PURPOSE:
//   This test contains a **deliberate bug** in the last step.
//   It verifies that the agent can detect, diagnose, and fix a test failure
//   mid-run using hot reload and retry — without restarting the test.
//
// EXPECTED AGENT WORKFLOW:
//   1. Connect to the running test via MCP (connect tool).
//   2. Run all steps at once (run_remaining).
//   3. Observe the failure in step 4 via get_test_state.
//   4. Read the error message — it says the expected text was not found.
//   5. Open this file, find the bug (wrong star count in the expected string).
//   6. Fix the assertion to match the actual rating (5 stars, not 3).
//   7. Hot reload (hot_reload_testwire_test) so the fix is picked up.
//   8. Retry the failed step (retry_step).
//   9. Verify step 4 now passes (get_test_state — status should be "fixed").
//  10. No more steps remain — report the final result.
//  11. Disconnect (disconnect).
//
// THE BUG:
//   Step 4 expects "3 stars from Alex" but the test taps star_5 (5-star rating).
//   The correct expected text is "5 stars from Alex".
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testwire_flutter/testwire_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testwire/testwire.dart';
import 'package:testwire_example/main.dart' as app;

class FixErrorDemo extends TestwireTest {
  FixErrorDemo()
    : super(
        'Submit feedback — agent must fix the deliberate bug',
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
      description: 'Tap 5-star rating',
      context: 'Tap the 5th star to set rating to 5.',
      action: () async {
        await tester.tap(find.byKey(const Key('star_5')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Enter comment',
      context: 'Type "Excellent!" into the comment field.',
      action: () async {
        await tester.enterText(
          find.byKey(const Key('comment_field')),
          'Excellent!',
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

    // BUG: expects "3 stars" but we tapped star_5 — should be "5 stars".
    await step(
      description: 'Verify success screen',
      context:
          'Check that the success message and rating summary are displayed.',
      action: () async {
        expect(find.text('Thank you for your feedback!'), findsOneWidget);
        expect(find.text('5 stars from Alex'), findsOneWidget);
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerTestwireExtensions();
  FixErrorDemo().run();
}
