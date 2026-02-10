import 'package:mcp_dart/mcp_dart.dart';
import 'package:testwire_protocol/testwire_protocol.dart' show StepStatus;

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

/// All MCP tools exposed by the testwire MCP server.
///
/// Each value carries the complete metadata required by
/// [McpServer.registerTool]: name, title, description, annotations, and input
/// schema.  The callbacks are intentionally *not* part of this enum — they live
/// in [VmServiceContext] which owns the [VmServiceConnector].
enum TestwireTool {
  connect(
    title: 'Connect to Test',
    description:
        'Connects to a Flutter test process via its VM service URI. '
        'This must be called before using any other tools. '
        'The VM service URI is typically in the format ws://127.0.0.1:PORT/ws '
        'and can be found in the Flutter test output when running in debug mode. '
        'This only establishes the connection -- it does NOT start the test. '
        'Use step_forward or run_remaining to start test execution.',
    inputSchema: JsonObject(
      properties: {
        'uri': JsonString(
          description:
              'VM service URI (e.g., ws://127.0.0.1:8181/ws). '
              'This is printed in the Flutter test console when running in debug mode.',
        ),
      },
      required: ['uri'],
    ),
  ),
  disconnect(
    title: 'Disconnect',
    description:
        'Disconnects from the currently connected Flutter test process. '
        'After disconnecting, you must call connect again to use any other tools.',
  ),
  getTestState(
    title: 'Get Test State',
    description:
        'Returns the current state of the test including all steps and their statuses. '
        'Each step shows its index, description, status (pending/running/passed/failed/fixed), '
        'and error details if failed. Also shows the overall test status '
        '(waiting/running/paused/passed/failed) and the current step index. '
        'This is read-only and can be called at any time after connecting.',
    annotations: ToolAnnotations(
      title: 'Get Test State',
      readOnlyHint: true,
      idempotentHint: true,
    ),
  ),
  stepForward(
    title: 'Step Forward',
    description:
        'Executes the next test step and pauses after it completes (step-by-step mode). '
        'If the test has not started yet, this signals the test to begin. '
        'If the test is paused after a failed step, this skips the failure and advances. '
        'After the step runs, the test pauses again so you can inspect the result '
        'with get_test_state.',
  ),
  runRemaining(
    title: 'Run Remaining',
    description:
        'Runs all remaining test steps automatically without pausing (auto mode). '
        'If the test has not started yet, this signals the test to begin. '
        'Steps execute one after another. The test only pauses when a step fails '
        'or when all steps have completed. Use get_test_state to check the result.',
  ),
  retryStep(
    title: 'Retry Step',
    description:
        'Re-executes the current failed step. Use this after fixing the issue '
        '(e.g., editing code and doing a hot_reload). The test always pauses after '
        'the retry so you can inspect the result. If the retry succeeds, the step '
        'status becomes "fixed" instead of "passed" for traceability.',
  ),
  hotReload(
    title: 'Hot Reload',
    description:
        'Performs a hot reload of the Flutter test process. This reloads Dart code '
        'without restarting the app, preserving the current state. Useful after '
        'editing test code to apply changes before the next step or retry.',
  ),
  hotRestart(
    title: 'Hot Restart',
    description:
        'Performs a full hot restart of the Flutter test process. This restarts '
        'the app and test from scratch, re-initializing all state. After restart, '
        'you must call connect again to re-establish the connection, then use '
        'step_forward or run_remaining to start the test.',
  );

  const TestwireTool({
    required this.title,
    required this.description,
    this.annotations,
    this.inputSchema = const JsonObject(properties: {}),
  });

  final String title;
  final String description;
  final ToolAnnotations? annotations;
  final JsonObject inputSchema;

  /// The tool name used in MCP registration.
  ///
  /// Converts camelCase enum names to snake_case
  /// (e.g. `getTestState` -> `get_test_state`).
  String get toolName => name.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );

  /// Resolved [ToolAnnotations] — uses [annotations] if provided, otherwise
  /// synthesises one from [title] alone.
  ToolAnnotations get resolvedAnnotations =>
      annotations ?? ToolAnnotations(title: title);

  /// Instructions text for the MCP server describing the full tool set.
  static String get serverInstructions => '''
Testwire MCP enables AI agents to control and observe Flutter integration tests running in debug mode. It provides step-by-step execution, retry on failure, and full visibility into test state.

Usage:
1. Start the Flutter integration test in debug mode with --dart-define=AGENT_MODE=true and note the VM service URI.
2. Use "connect" with the VM service URI to establish a connection. The test will be waiting.
3. Use "step_forward" to run one step at a time, or "run_remaining" to run all steps automatically.
4. Use "get_test_state" to see all steps and their statuses (pending/running/passed/failed/fixed).
5. If a step fails, inspect the error, fix the code, use "hot_reload" to apply changes, then "retry_step".
6. Use "hot_restart" to restart the entire test from scratch (requires reconnecting).

Step statuses:
${StepStatus.values.map((s) => '- ${s.name}: ${s.description}').join('\n')}
''';
}
