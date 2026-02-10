import 'dart:async';

import 'package:testwire/src/step_registry.dart';

// ---------------------------------------------------------------------------
// Resume signal (moved from step.dart)
// ---------------------------------------------------------------------------

/// Signal sent by the agent to resume test execution after a pause.
enum ResumeSignal {
  /// Move to the next step.
  advance,

  /// Re-execute the current step.
  retry,
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
TestSession startSession() {
  final session = TestSession();
  _activeSession = session;
  return session;
}
