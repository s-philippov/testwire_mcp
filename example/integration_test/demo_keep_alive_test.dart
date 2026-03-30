// =============================================================================
// DEMO 4 — Keep-Alive (UI stays responsive between steps)
// =============================================================================
//
// PURPOSE:
//   This test demonstrates the keep-alive feature that keeps the Flutter UI
//   responsive while testwire waits for the agent between steps.
//
//   Without keep-alive, `tester.pump()` is never called while the agent is
//   thinking, so async operations (network calls, timers, animations) freeze.
//   With keep-alive, frames are pumped continuously during pauses, so the
//   app processes callbacks normally.
//
// THE KEY MOMENT:
//   Step 2 taps "Check Server" which starts a simulated 2-second network call.
//   The step completes immediately after the tap + a single pump.
//   During the pause (while the agent decides to advance), the keep-alive
//   mechanism continues pumping frames, allowing the Future.delayed to
//   complete and the UI to transition from "loading" → "Server is online".
//   Step 3 then verifies the result is visible — this would FAIL without
//   keep-alive because the 2-second timer would never fire.
//
// EXPECTED AGENT WORKFLOW:
//   1. Connect to the running test via MCP (connect tool).
//   2. Step forward through each step (step_forward), or run_remaining.
//   3. All 3 steps should pass. If keep-alive is broken, step 3 will fail
//      with a timeout because "Server is online" never appears.
//   4. Disconnect (disconnect).
//
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testwire/testwire.dart';
import 'package:testwire_flutter/testwire_flutter.dart';
import 'package:testwire_example/main.dart' as app;

class KeepAliveDemo extends TestwireTest {
  KeepAliveDemo() : super('Keep-alive — UI stays responsive between steps');

  @override
  Future<void> setUp(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
  }

  @override
  Future<void> body(WidgetTester tester) async {
    await step(
      description: 'Navigate to Server Status',
      context: 'Tap the "Check Server Status" tile on the home screen.',
      action: () async {
        await tester.tap(find.byKey(const Key('check_server_tile')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Tap Check Server button',
      context:
          'Tap the button to start the simulated network call. '
          'This triggers a 2-second Future.delayed. The step completes '
          'immediately — the keep-alive mechanism will pump frames during '
          'the pause so the timer can fire.',
      action: () async {
        await tester.tap(find.byKey(const Key('check_server_button')));
        await tester.pump();
        // Verify we see the loading indicator.
        expect(find.byKey(const Key('loading_indicator')), findsOneWidget);
      },
    );

    await step(
      description: 'Verify server is online',
      context:
          'The 2-second network call should have completed during the '
          'keep-alive pumping between steps. Verify the result is visible. '
          'Without keep-alive this step would fail — the UI would still '
          'show the loading spinner.',
      action: () async {
        // Give the UI a moment to process any remaining callbacks.
        await tester.pumpAndSettle();
        expect(find.text('Server is online'), findsOneWidget);
        expect(find.text('Response time: 2000ms'), findsOneWidget);
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerTestwireExtensions();
  KeepAliveDemo().run();
}
