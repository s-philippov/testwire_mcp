/// Flutter integration test wrapper for testwire with hot-reload support.
///
/// Provides two ways to write tests:
///
/// ### [TestwireTest] — class-based, full hot-reload support
///
/// Override [TestwireTest.body] so the Dart VM patches your test steps via
/// virtual dispatch after a hot reload.
///
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
///
/// ### [testwireTest] — function-based, no hot-reload for body
///
/// A simpler `testWidgets` wrapper for tests that don't need hot-reload
/// (e.g. CI-only tests).
///
/// ```dart
/// testwireTest('My test', (tester) async {
///   await step(
///     description: 'App shows welcome screen',
///     action: () async {
///       expect(find.text('Welcome'), findsOneWidget);
///     },
///   );
/// },
/// setUp: (tester) async {
///   app.main();
///   await tester.pumpAndSettle();
/// });
/// ```
library;

export 'src/screenshot_service.dart' show ScreenshotService;
export 'src/testwire_test.dart' show TestwireTest, testwireTest;
