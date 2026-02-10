/// Testwire -- step-based test execution for Flutter integration tests
/// with AI agent control.
///
/// Usage in integration test:
/// ```dart
/// import 'package:testwire/testwire.dart';
///
/// void main() {
///   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
///   registerTestwireExtensions();
///
///   testWidgets('My test', (tester) async {
///     await waitForAgentConnection();
///     app.main();
///     await tester.pumpAndSettle();
///
///     await step(
///       description: 'App shows welcome screen',
///       action: () async {
///         expect(find.text('Welcome'), findsOneWidget);
///       },
///     );
///   });
/// }
/// ```
library;

export 'src/agent.dart' show isAgentMode, waitForAgentConnection;
export 'src/extensions.dart' show registerTestwireExtensions;
export 'src/step.dart' show step;
export 'src/step_registry.dart' show StepRegistry, StepState;

// Re-export shared protocol types so downstream consumers don't need a
// direct dependency on testwire_protocol.
export 'package:testwire_protocol/testwire_protocol.dart'
    show ExtensionResponse, StepStatus, TestStatus, TestwireExtension;
