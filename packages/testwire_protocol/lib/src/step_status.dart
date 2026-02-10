/// Step statuses representing the lifecycle of a test step.
///
/// Shared between the Flutter-side `testwire` library and the MCP server.
enum StepStatus {
  /// Step is registered but has not started yet.
  pending('Not yet executed', '[...]'),

  /// Step is currently executing its action.
  running('Currently executing', '[RUN]'),

  /// Step action completed successfully.
  passed('Completed successfully', '[PASS]'),

  /// Step action threw an exception.
  failed('Threw an exception (error details available)', '[FAIL]'),

  /// Step was previously [failed], agent retried, and retry succeeded.
  fixed('Was failed, agent retried after fix, now passes', '[FIXED]');

  const StepStatus(this.description, this.indicator);

  /// Human-readable description of this status.
  final String description;

  /// Short indicator token for formatted output (e.g. `[PASS]`, `[FAIL]`).
  final String indicator;

  /// Resolves a raw status string (e.g. from JSON) to a [StepStatus].
  ///
  /// Returns `null` for unknown values.
  static StepStatus? tryParse(String value) =>
      StepStatus.values.asNameMap()[value];
}
