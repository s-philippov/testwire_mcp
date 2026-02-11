/// Sentinel exception thrown by [step] when a hot reload notification
/// is received mid-test.
///
/// Caught by `testwireTest` in the `testwire_flutter` package to re-call
/// the test body with the updated function definition.
class HotReloadInterrupt implements Exception {
  /// Creates a [HotReloadInterrupt].
  const HotReloadInterrupt();

  @override
  String toString() =>
      'HotReloadInterrupt: '
      'test body will be re-called with updated code.';
}
