/// Overall status of a testwire test run.
///
/// Derived from the individual [StepStatus] values of all registered steps.
enum TestStatus {
  /// No steps registered yet; test is waiting to start.
  waiting,

  /// At least one step is currently executing.
  running,

  /// Some steps are still pending; test is paused between steps.
  paused,

  /// All steps completed successfully (passed or fixed).
  passed,

  /// At least one step has failed and none are running.
  failed;

  /// Resolves a raw status string (e.g. from JSON) to a [TestStatus].
  ///
  /// Returns `null` for unknown values.
  static TestStatus? tryParse(String value) =>
      TestStatus.values.asNameMap()[value];
}
