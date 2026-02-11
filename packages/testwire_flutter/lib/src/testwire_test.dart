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
/// Subclass this and override [body] with your `step()` calls.
/// After a hot reload, `body()` is dispatched via the class vtable, so the
/// Dart VM always picks up the patched method body — unlike closures which
/// retain their old code once allocated.
///
/// Example:
/// ```dart
/// class FeedbackTest extends TestwireTest {
///   FeedbackTest()
///       : super(
///           'Feedback form flow',
///           setUp: (tester) async {
///             app.main();
///             await tester.pumpAndSettle();
///           },
///         );
///
///   @override
///   Future<void> body(WidgetTester tester) async {
///     await step(
///       description: 'Enter name',
///       action: () async { /* ... */ },
///     );
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
  ///
  /// [setUp] runs once before the first body call (e.g. to launch the app)
  /// and is **not** re-executed after a hot reload.
  TestwireTest(
    this.description, {
    this.setUp,
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

  /// Optional one-time setup (e.g. launching the app).
  final Future<void> Function(WidgetTester tester)? setUp;

  // -- testWidgets forwarding parameters --
  final bool? skip;
  final Timeout? timeout;
  final bool semanticsEnabled;
  final TestVariant<Object?> variant;
  final dynamic tags;
  final int? retry;
  final LeakTesting? experimentalLeakTesting;

  /// The test body containing `step()` calls.
  ///
  /// Override this in your subclass. After a hot reload the Dart VM patches
  /// this method via the class vtable, so the new code executes on the next
  /// loop iteration — no need to restart the test.
  Future<void> body(WidgetTester tester);

  /// Registers and runs the test via `testWidgets`.
  ///
  /// Typically called once from `main()`.
  void run() {
    _registerScreenshotExtension();

    testWidgets(
      description,
      (tester) async {
        await waitForAgentConnection();

        if (setUp case final fn?) {
          await fn(tester);
        }

        // Virtual dispatch → always calls the latest (patched) body.
        await runTestLoop(activeSession, () => body(tester));
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

      if (setUp != null) {
        await setUp(tester);
      }

      await runTestLoop(activeSession, () => body(tester));
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
