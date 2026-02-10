/// VM service extensions registered by testwire.
///
/// Each value maps to a fully-qualified extension method name used in
/// `dart:developer.registerExtension()` on the Flutter side and
/// `VmService.callServiceExtension()` on the MCP server side.
enum TestwireExtension {
  /// Returns the full test state as JSON.
  getState('ext.flutter.testwire.getState'),

  /// Starts the test or advances one step (step-by-step mode).
  stepForward('ext.flutter.testwire.stepForward'),

  /// Starts the test or runs all remaining steps (auto mode).
  runRemaining('ext.flutter.testwire.runRemaining'),

  /// Retries the current failed step.
  retry('ext.flutter.testwire.retry'),

  /// Signals the test that the agent is disconnecting.
  ///
  /// The test stops pausing and runs all remaining steps automatically,
  /// as if [runRemaining] was called.
  disconnect('ext.flutter.testwire.disconnect');

  const TestwireExtension(this.method);

  /// Fully-qualified extension method name
  /// (e.g. `ext.flutter.testwire.getState`).
  final String method;
}
