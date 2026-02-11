import 'dart:async';

import 'package:testwire/src/step_registry.dart';

// ---------------------------------------------------------------------------
// Resume signal
// ---------------------------------------------------------------------------

/// Signal sent by the agent to resume test execution after a pause.
enum ResumeSignal {
  /// Move to the next step.
  advance,

  /// Re-execute the current step.
  retry,

  /// Abort the current body execution so the wrapper can re-call it
  /// with the hot-reloaded function definition.
  hotReload,
}

// ---------------------------------------------------------------------------
// TestSession
// ---------------------------------------------------------------------------

/// Per-test session that owns all mutable state for a single `testWidgets`
/// invocation.
///
/// A new instance is created by [waitForAgentConnection] at the start of
/// every test, replacing the previous session.  VM service extension
/// callbacks always read [activeSession] so they talk to whichever test
/// is currently running.
class TestSession {
  /// Creates a new session.
  ///
  /// [agentMode] defaults to the compile-time `AGENT_MODE` flag but can be
  /// overridden in tests to simulate agent behaviour without
  /// `--dart-define=AGENT_MODE=true`.
  TestSession({bool? agentMode}) : agentMode = agentMode ?? _defaultAgentMode;

  /// Whether this session is running in agent mode.
  ///
  /// When `true`, steps pause after execution so the AI agent can inspect
  /// state and control the test flow.
  final bool agentMode;

  /// Fresh step registry for this test.
  final StepRegistry registry = StepRegistry();

  /// Whether the agent has signaled readiness for this test run.
  bool agentConnected = false;

  /// Completer resolved when the agent first calls `stepForward` or
  /// `runRemaining`.
  Completer<void>? agentCompleter;

  /// Whether to pause after every step (`true` = step-by-step, `false` =
  /// auto / only on failure).
  bool pauseAfterEveryStep = true;

  /// Completer used to pause test execution between steps in agent mode.
  Completer<ResumeSignal>? pauseCompleter;

  /// Completer used by the `testwireTest` wrapper to keep the test alive
  /// after all current steps have completed (post-body pause).
  ///
  /// Separated from [pauseCompleter] so that `step_forward` / `run_remaining`
  /// cannot accidentally resolve it — only [notifyHotReload] and [disconnect]
  /// can.
  Completer<ResumeSignal>? postBodyCompleter;

  // -- Agent connection -----------------------------------------------------

  /// Marks the agent as connected and completes [agentCompleter].
  void signalAgentConnected() {
    agentConnected = true;
    if (agentCompleter case final c? when !c.isCompleted) {
      c.complete();
    }
  }

  // -- Step resume / retry --------------------------------------------------

  /// Resumes the paused test, advancing to the next step.
  ///
  /// If the test has not started yet, signals agent connection first.
  void resumeTest({required bool pauseAfterEveryStep}) {
    this.pauseAfterEveryStep = pauseAfterEveryStep;

    if (!agentConnected) {
      signalAgentConnected();
      return;
    }

    if (pauseCompleter case final c? when !c.isCompleted) {
      c.complete(ResumeSignal.advance);
    }
  }

  /// Signals the test to retry the current (failed) step.
  ///
  /// Always forces pause-after-step so the agent sees the retry result.
  void retryCurrentStep() {
    pauseAfterEveryStep = true;

    if (pauseCompleter case final c? when !c.isCompleted) {
      c.complete(ResumeSignal.retry);
    }
  }

  // -- Hot reload --------------------------------------------------------------

  /// Whether a hot reload has been performed and the test body should be
  /// re-called from the wrapper loop.
  bool hotReloadPending = false;

  /// Number of steps that have completed execution (passed, fixed, or
  /// skipped-after-failure). Persists across body re-calls so already
  /// executed steps are skipped on re-entry.
  int completedStepCount = 0;

  /// Called by the MCP server after a successful hot reload.
  ///
  /// Sets [hotReloadPending] and unblocks the current pause so `step()`
  /// can throw [HotReloadInterrupt] at the next step boundary.
  void notifyHotReload() {
    hotReloadPending = true;

    if (pauseCompleter case final c? when !c.isCompleted) {
      c.complete(ResumeSignal.hotReload);
    }
    if (postBodyCompleter case final c? when !c.isCompleted) {
      c.complete(ResumeSignal.hotReload);
    }
  }

  // -- Disconnect -------------------------------------------------------------

  /// Whether the agent has explicitly disconnected from this session.
  bool agentDisconnected = false;

  /// Signals that the agent is disconnecting.
  ///
  /// Unblocks every pending completer so the test runs to completion
  /// without further pauses — equivalent to calling [resumeTest] with
  /// `pauseAfterEveryStep: false`, but also handles the case where the
  /// test has not started yet (unblocks [agentCompleter]).
  void disconnect() {
    agentDisconnected = true;
    pauseAfterEveryStep = false;

    // Unblock waitForAgentConnection() if still waiting.
    if (agentCompleter case final c? when !c.isCompleted) {
      c.complete();
    }

    // Unblock the current step pause if any.
    if (pauseCompleter case final c? when !c.isCompleted) {
      c.complete(ResumeSignal.advance);
    }

    // Unblock post-body pause if waiting.
    if (postBodyCompleter case final c? when !c.isCompleted) {
      c.complete(ResumeSignal.advance);
    }
  }
}

// ---------------------------------------------------------------------------
// Active session pointer
// ---------------------------------------------------------------------------

TestSession? _activeSession;

/// The currently active [TestSession].
///
/// Set by [waitForAgentConnection] at the start of each test.
/// Throws [StateError] if accessed before any test has started.
TestSession get activeSession {
  final session = _activeSession;
  if (session == null) {
    throw StateError(
      'No active testwire session. '
      'Call waitForAgentConnection() at the start of your test.',
    );
  }
  return session;
}

/// Creates a fresh [TestSession] and sets it as the active session.
///
/// Called internally by [waitForAgentConnection].
/// Pass [agentMode] to override the compile-time default (useful in tests).
TestSession startSession({bool? agentMode}) {
  final session = TestSession(agentMode: agentMode);
  _activeSession = session;
  return session;
}

/// Default agent mode from compile-time environment.
const bool _defaultAgentMode = bool.fromEnvironment('AGENT_MODE');
