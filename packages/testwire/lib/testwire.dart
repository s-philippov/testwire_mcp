/// Testwire -- step-based test execution for Flutter integration tests
/// with AI agent control.
///
/// Usage with `testwire_flutter` (recommended):
/// ```dart
/// import 'package:testwire_flutter/testwire_flutter.dart';
/// import 'package:testwire/testwire.dart';
///
/// class MyTest extends TestwireTest {
///   MyTest() : super('My test', setUp: (tester) async {
///     app.main();
///     await tester.pumpAndSettle();
///   });
///
///   @override
///   Future<void> body(WidgetTester tester) async {
///     await step(
///       description: 'App shows welcome screen',
///       action: () async {
///         expect(find.text('Welcome'), findsOneWidget);
///       },
///     );
///   }
/// }
///
/// void main() {
///   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
///   registerTestwireExtensions();
///   MyTest().run();
/// }
/// ```
library;

export 'src/agent.dart' show isAgentMode, waitForAgentConnection;
export 'src/extensions.dart' show registerTestwireExtensions;
export 'src/session.dart'
    show ResumeSignal, TestSession, activeSession, startSession;
export 'src/step.dart' show step;
export 'src/test_runner_loop.dart' show runTestLoop;
export 'src/step_registry.dart' show StepRegistry, StepState;

// Re-export shared protocol types so downstream consumers don't need a
// direct dependency on testwire_protocol.
export 'package:testwire_protocol/testwire_protocol.dart'
    show ExtensionResponse, StepStatus, TestStatus, TestwireExtension;
