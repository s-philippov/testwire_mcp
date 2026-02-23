import 'package:logging/logging.dart' as logging;
import 'package:mcp_dart/mcp_dart.dart';
import 'package:testwire_protocol/testwire_protocol.dart'
    show ExtensionResponse, StepStatus;

import 'package:testwire_mcp/src/device_control.dart';
import 'package:testwire_mcp/src/tool_definitions.dart';
import 'package:testwire_mcp/src/vm_service_connector.dart';

/// Registers all testwire MCP tools with the server.
final class VmServiceContext {
  VmServiceContext()
    : connector = VmServiceConnector(),
      deviceControl = DeviceControl(),
      _logger = logging.Logger('VmServiceContext');

  final VmServiceConnector connector;
  final DeviceControl deviceControl;
  final logging.Logger _logger;

  /// Registers all testwire MCP tools with the [server].
  ///
  /// Tool metadata (names, descriptions, schemas, annotations) is defined in
  /// the [TestwireTool] enum.  This method wires each tool to its callback.
  void registerTools(McpServer server) {
    for (final tool in TestwireTool.values) {
      server.registerTool(
        tool.toolName,
        title: tool.title,
        description: tool.description,
        annotations: tool.resolvedAnnotations,
        inputSchema: tool.inputSchema,
        callback: _callbackFor(tool),
      );
    }
  }

  ToolFunction _callbackFor(TestwireTool tool) => switch (tool) {
    TestwireTool.connect => _connect,
    TestwireTool.disconnect => _disconnect,
    TestwireTool.getTestState => _getTestState,
    TestwireTool.stepForward => _stepForward,
    TestwireTool.runRemaining => _runRemaining,
    TestwireTool.retryStep => _retryStep,
    TestwireTool.hotReloadTestwireTest => _hotReload,
    TestwireTool.hotRestartTestwireTest => _hotRestart,
    TestwireTool.screenshot => _screenshot,
    TestwireTool.grantAllPermissions => _grantAllPermissions,
    TestwireTool.revokeAllPermissions => _revokeAllPermissions,
  };

  // ---- Tool callbacks ----

  Future<CallToolResult> _connect(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    final uri = args['uri'] as String;
    _logger.info('Connecting to test at $uri');

    try {
      await connector.connect(uri);
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Connected to test process at $uri. '
                'Test is waiting. Call step_forward to run one step, '
                'or run_remaining to run all steps.',
          ),
        ],
      );
    } catch (err) {
      _logger.severe('Failed to connect', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to connect: $err')],
      );
    }
  }

  Future<CallToolResult> _disconnect(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    final terminateApp = args['terminate_app'] as bool? ?? true;
    _logger.info('Disconnecting (terminate_app: $terminateApp)');

    try {
      await connector.disconnect(terminateApp: terminateApp);

      final suffix = terminateApp
          ? ' The application process has been terminated.'
          : '';
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Disconnected from test process. '
                'The test will run all remaining steps automatically.$suffix',
          ),
        ],
      );
    } catch (err) {
      _logger.severe('Error during disconnect', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Error during disconnect: $err')],
      );
    }
  }

  Future<CallToolResult> _getTestState(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Getting test state');

    try {
      final state = await connector.getTestState();
      return CallToolResult(
        content: [TextContent(text: _formatTestState(state))],
      );
    } catch (err) {
      _logger.warning('Failed to get test state', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: err.toString())],
      );
    }
  }

  Future<CallToolResult> _stepForward(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Stepping forward');

    try {
      final raw = await connector.stepForward();
      final response = ExtensionResponse.fromMap(raw);
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Step forward (${response.mode} mode). '
                'Use get_test_state to see the result.',
          ),
        ],
      );
    } catch (err) {
      _logger.warning('Failed to step forward', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: err.toString())],
      );
    }
  }

  Future<CallToolResult> _runRemaining(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Running remaining steps');

    try {
      final raw = await connector.runRemaining();
      final response = ExtensionResponse.fromMap(raw);
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Running remaining steps (${response.mode} mode). '
                'Test will pause on failure or when all steps complete. '
                'Use get_test_state to check progress.',
          ),
        ],
      );
    } catch (err) {
      _logger.warning('Failed to run remaining', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: err.toString())],
      );
    }
  }

  Future<CallToolResult> _retryStep(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Retrying current step');

    try {
      await connector.retryStep();
      return CallToolResult(
        content: [
          const TextContent(
            text:
                'Retrying current step. Test will pause after retry. '
                'Use get_test_state to see if it passed (status will be "fixed").',
          ),
        ],
      );
    } catch (err) {
      _logger.warning('Failed to retry step', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: err.toString())],
      );
    }
  }

  Future<CallToolResult> _hotReload(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Performing hot reload');

    try {
      final success = await connector.hotReload();

      if (success) {
        return CallToolResult(
          content: [
            const TextContent(
              text:
                  'Hot reload completed successfully. '
                  'The test will re-enter the body, skipping already-completed '
                  'steps and executing new or modified ones. '
                  'Use get_test_state to see the updated steps.',
            ),
          ],
        );
      } else {
        return CallToolResult(
          isError: true,
          content: [
            const TextContent(
              text: 'Hot reload failed. The app may need a full restart.',
            ),
          ],
        );
      }
    } catch (err) {
      _logger.warning('Failed to perform hot reload', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Hot reload failed: $err')],
      );
    }
  }

  Future<CallToolResult> _hotRestart(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Performing hot restart');

    try {
      await connector.hotRestart();
      return CallToolResult(
        content: [
          const TextContent(
            text:
                'Hot restart triggered. The test process is restarting. '
                'Call connect again with the VM service URI, then use '
                'step_forward or run_remaining to start the test.',
          ),
        ],
      );
    } catch (err) {
      _logger.warning('Hot restart error', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Hot restart failed: $err')],
      );
    }
  }

  Future<CallToolResult> _screenshot(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    _logger.info('Taking screenshot');

    try {
      final screenshots = await connector.takeScreenshots();

      if (screenshots.isEmpty) {
        return CallToolResult(
          content: [
            const TextContent(text: 'No render views available for capture.'),
          ],
        );
      }

      return CallToolResult(
        content: [
          for (final base64Png in screenshots)
            ImageContent(data: base64Png, mimeType: 'image/png'),
        ],
      );
    } catch (err) {
      _logger.warning('Failed to take screenshot', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Screenshot failed: $err')],
      );
    }
  }

  Future<CallToolResult> _grantAllPermissions(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    final appId = args['app_id'] as String;
    _logger.info('Granting all permissions for $appId');

    try {
      final result = await deviceControl.grantAllPermissions(appId);
      return CallToolResult(
        content: [TextContent(text: result)],
      );
    } catch (err) {
      _logger.warning('Failed to grant permissions', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to grant permissions: $err')],
      );
    }
  }

  Future<CallToolResult> _revokeAllPermissions(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    final appId = args['app_id'] as String;
    _logger.info('Revoking all permissions for $appId');

    try {
      final result = await deviceControl.revokeAllPermissions(appId);
      return CallToolResult(
        content: [TextContent(text: result)],
      );
    } catch (err) {
      _logger.warning('Failed to revoke permissions', err);
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to revoke permissions: $err')],
      );
    }
  }

  // ---- Formatting ----

  String _formatTestState(Map<String, dynamic> state) {
    final buffer = StringBuffer();

    final status = state['status'] ?? 'unknown';
    final currentStep = state['currentStep'];
    buffer.writeln('Test status: $status');
    if (currentStep != null) {
      buffer.writeln('Current step: $currentStep');
    }

    final steps = state['steps'] as List<dynamic>? ?? [];
    if (steps.isEmpty) {
      buffer.writeln('No steps registered yet.');
    } else {
      buffer.writeln('Steps (${steps.length}):');
      for (final step in steps) {
        final s = step as Map<String, dynamic>;
        final idx = s['index'];
        final desc = s['description'] ?? '';
        final stepStatus = s['status'] ?? 'unknown';
        final ctx = s['context'] as String?;
        final error = s['error'] as String?;

        final status = StepStatus.tryParse(stepStatus as String);
        final indicator = status?.indicator ?? '[???]';

        buffer.writeln('  $indicator $idx: $desc');
        if (ctx != null) buffer.writeln('         context: $ctx');
        if (error != null) buffer.writeln('         error: $error');
      }
    }

    return buffer.toString().trimRight();
  }
}
