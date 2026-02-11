// =============================================================================
// DEMO 2 — Incremental Development Flow
// =============================================================================
//
// PURPOSE:
//   This test starts with only ONE active step. The remaining steps are
//   commented out. It verifies that the agent can add new steps to a running
//   test via hot reload — simulating incremental test development.
//
// EXPECTED AGENT WORKFLOW:
//   1. Connect to the running test via MCP (connect tool).
//   2. Step forward (step_forward) to execute the only available step.
//   3. Check state (get_test_state) — step 0 should pass. The test is now
//      paused with no more steps to run.
//   4. Open this file and uncomment the remaining steps below the
//      "TODO(agent)" marker.
//   5. Hot reload (hot_reload_testwire_test) to inject the new steps.
//   6. Run remaining steps (run_remaining) — they should all pass.
//   7. Check final state (get_test_state) — all 5 steps should be PASS.
//   8. Report the result.
//   9. Disconnect (disconnect).
//
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testwire_flutter/testwire_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testwire/testwire.dart';
import 'package:testwire_example/main.dart' as app;

class IncrementalDemo extends TestwireTest {
  IncrementalDemo()
    : super(
        'Submit feedback — agent must uncomment remaining steps',
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

    // TODO(agent): Uncomment the steps below, then hot-reload.

    // await step(
    //   description: 'Tap 3-star rating',
    //   context: 'Tap the 3rd star to set rating to 3.',
    //   action: () async {
    //     await tester.tap(find.byKey(const Key('star_3')));
    //     await tester.pumpAndSettle();
    //   },
    // );
    //
    // await step(
    //   description: 'Enter comment',
    //   context: 'Type "Nice app!" into the comment field.',
    //   action: () async {
    //     await tester.enterText(
    //       find.byKey(const Key('comment_field')),
    //       'Nice app!',
    //     );
    //     await tester.pumpAndSettle();
    //   },
    // );
    //
    // await step(
    //   description: 'Tap submit button',
    //   context: 'Tap the Submit button to send the form.',
    //   action: () async {
    //     await tester.tap(find.byKey(const Key('submit_button')));
    //     await tester.pumpAndSettle();
    //   },
    // );
    //
    // await step(
    //   description: 'Verify success screen',
    //   context:
    //       'Check that the success message and rating summary are displayed.',
    //   action: () async {
    //     expect(find.text('Thank you for your feedback!'), findsOneWidget);
    //     expect(find.text('3 stars from Alex'), findsOneWidget);
    //   },
    // );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerTestwireExtensions();
  IncrementalDemo().run();
}
