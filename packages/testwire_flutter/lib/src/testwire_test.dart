import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:testwire/testwire.dart';

import 'screenshot_service.dart';

// ---------------------------------------------------------------------------
// TestwireTest — abstract base class (hot-reload-safe)
// ---------------------------------------------------------------------------

/// Base class for testwire integration tests with **full hot-reload support**.
///
/// Subclass this and override [setUp], [body], and optionally [tearDown].
/// All three are dispatched via the class vtable, so the Dart VM picks up
/// patched method bodies after a hot reload — unlike closures which retain
/// their old code once allocated.
///
/// Lifecycle:
///   [setUp] → [body] (inside [runTestLoop]) → [tearDown]
///
/// [setUp] runs once before the first body call (e.g. to launch the app)
/// and is **not** re-executed after a hot reload.
///
/// [tearDown] always runs in a `finally` block:
/// - **Agent mode:** after the agent calls `disconnect`.
/// - **CI mode:** immediately after all steps complete.
///
/// Example:
/// ```dart
/// class FeedbackTest extends TestwireTest {
///   FeedbackTest() : super('Feedback form flow');
///
///   @override
///   Future<void> setUp(WidgetTester tester) async {
///     app.main();
///     await tester.pumpAndSettle();
///   }
///
///   @override
///   Future<void> body(WidgetTester tester) async {
///     await step(
///       description: 'Enter name',
///       action: () async { /* ... */ },
///     );
///   }
///
///   @override
///   Future<void> tearDown(WidgetTester tester) async {
///     await signOut();
///   }
/// }
///
/// void main() {
///   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
///   registerTestwireExtensions();
///   FeedbackTest().run();
/// }
/// ```
abstract class TestwireTest {
  /// Creates a test case with the given [description].
  TestwireTest(
    this.description, {
    this.skip,
    this.timeout,
    this.semanticsEnabled = true,
    this.variant = const DefaultTestVariant(),
    this.tags,
    this.retry,
    this.experimentalLeakTesting,
  });

  /// Human-readable test description passed to `testWidgets`.
  final String description;

  // -- testWidgets forwarding parameters --
  final bool? skip;
  final Timeout? timeout;
  final bool semanticsEnabled;
  final TestVariant<Object?> variant;
  final dynamic tags;
  final int? retry;
  final LeakTesting? experimentalLeakTesting;

  /// One-time setup (e.g. launching the app).
  ///
  /// Runs once before the first [body] call and is **not** re-executed
  /// after a hot reload. Override in your subclass if needed.
  Future<void> setUp(WidgetTester tester) async {}

  /// The test body containing `step()` calls.
  ///
  /// Override this in your subclass. After a hot reload the Dart VM patches
  /// this method via the class vtable, so the new code executes on the next
  /// loop iteration — no need to restart the test.
  Future<void> body(WidgetTester tester);

  /// Cleanup callback that runs after the test loop ends.
  ///
  /// Runs after the test loop ends — by default when the agent calls
  /// `disconnect` (agent mode) or immediately after all steps (CI mode).
  ///
  /// With `--dart-define=TEAR_DOWN_AFTER_STEPS=true`, runs right after the
  /// last step completes but before the post-body pause, so the agent can
  /// still inspect the app while tearDown has already cleaned up
  /// server-side resources.
  ///
  /// Override in your subclass if needed (e.g. to delete test users,
  /// sign out, dispose resources).
  Future<void> tearDown(WidgetTester tester) async {}

  /// Registers and runs the test via `testWidgets`.
  ///
  /// Typically called once from `main()`.
  void run() {
    _registerScreenshotExtension();

    testWidgets(
      description,
      (tester) async {
        await waitForAgentConnection();

        // Keep the UI alive while the agent is thinking between steps.
        activeSession.keepAlive =
            () => tester.pump(TestSession.keepAliveInterval);

        await setUp(tester);

        var tearDownDone = false;

        if (tearDownAfterSteps) {
          activeSession.onStepsComplete = () async {
            tearDownDone = true;
            await tearDown(tester);
          };
        }

        try {
          await runTestLoop(activeSession, () => body(tester));
        } finally {
          if (!tearDownDone) {
            await tearDown(tester);
          }
        }
      },
      skip: skip,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: variant,
      tags: tags,
      retry: retry,
      experimentalLeakTesting: experimentalLeakTesting,
    );
  }
}

// ---------------------------------------------------------------------------
// testwireTest — convenience function (no hot-reload for body)
// ---------------------------------------------------------------------------

/// A wrapper around [testWidgets] that adds agent-control support (step-based
/// pause/resume, disconnect, etc.) for testwire integration tests.
///
/// **Hot-reload limitation:** because [body] is a closure captured once in
/// `main()`, the Dart VM will not update its code after a hot reload. Use
/// [TestwireTest] (the class-based API) if you need hot-reload support for
/// adding/modifying steps at runtime.
///
/// All named parameters from [testWidgets] are forwarded as-is (e.g.
/// [skip], [timeout], [semanticsEnabled], [variant], [tags], [retry]).
///
/// The extra [setUp] callback runs once at the start of the test (e.g.
/// launching the app) and is **not** re-executed after a hot reload.
///
/// Example:
/// ```dart
/// testwireTest(
///   'Feedback form flow',
///   (tester) async {
///     await step(
///       description: 'Enter name',
///       action: () async { /* ... */ },
///     );
///   },
///   setUp: (tester) async {
///     app.main();
///     await tester.pumpAndSettle();
///   },
/// );
/// ```
void testwireTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Future<void> Function(WidgetTester tester)? setUp,
  Future<void> Function(WidgetTester tester)? tearDown,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
  LeakTesting? experimentalLeakTesting,
}) {
  _registerScreenshotExtension();

  testWidgets(
    description,
    (tester) async {
      await waitForAgentConnection();

      // Keep the UI alive while the agent is thinking between steps.
      activeSession.keepAlive =
          () => tester.pump(TestSession.keepAliveInterval);

      if (setUp != null) {
        await setUp(tester);
      }

      var tearDownDone = false;

      if (tearDown != null && tearDownAfterSteps) {
        activeSession.onStepsComplete = () async {
          tearDownDone = true;
          await tearDown(tester);
        };
      }

      try {
        await runTestLoop(activeSession, () => body(tester));
      } finally {
        if (!tearDownDone && tearDown != null) {
          await tearDown(tester);
        }
      }
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
    retry: retry,
    experimentalLeakTesting: experimentalLeakTesting,
  );
}

// ---------------------------------------------------------------------------
// Screenshot VM extension (auto-registered)
// ---------------------------------------------------------------------------

bool _screenshotExtensionRegistered = false;
final ScreenshotService _screenshotService = const ScreenshotService();

/// Registers the [TestwireExtension.screenshot] VM service extension once.
///
/// Called automatically from both [TestwireTest.run] and [testwireTest].
void _registerScreenshotExtension() {
  if (_screenshotExtensionRegistered) return;
  _screenshotExtensionRegistered = true;

  developer.registerExtension(TestwireExtension.screenshot.method, (
    method,
    parameters,
  ) async {
    final screenshots = await _screenshotService.takeScreenshots();
    final responseJson = jsonEncode({
      'status': 'Success',
      'screenshots': screenshots,
    });
    return developer.ServiceExtensionResponse.result(responseJson);
  });
}
