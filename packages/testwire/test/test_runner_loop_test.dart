import 'dart:async';

import 'package:test/test.dart';
import 'package:testwire/testwire.dart';

/// Pumps the event queue until [condition] is true, or throws on timeout.
///
/// Each iteration yields to both microtask and event queues via
/// `Future.delayed(Duration.zero)`, which ensures all pending microtask
/// chains settle before we re-check.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed > timeout) {
      throw TimeoutException('waitUntil timed out', timeout);
    }
    await Future<void>.delayed(Duration.zero);
  }
}

/// Pumps the event queue [times] iterations, letting all pending microtask
/// chains settle between iterations.
Future<void> pump([int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestSession session;

  setUp(() {
    session = startSession(agentMode: true);
    // Skip the agent handshake that waitForAgentConnection() would do.
    // Without this, the first resumeTest() call just marks the agent as
    // connected (signalAgentConnected) instead of advancing the step.
    session.agentConnected = true;
  });

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Creates a body that calls `step()` [count] times.
  /// Each step's action simply completes.
  Future<void> Function() bodyWithSteps(int count) {
    return () async {
      for (var i = 0; i < count; i++) {
        await step(description: 'Step $i', action: () async {});
      }
    };
  }

  /// Waits for a step to pause (pauseCompleter is set and not completed),
  /// then advances it.
  Future<void> advanceOneStep() async {
    await waitUntil(
      () =>
          session.pauseCompleter != null &&
          !session.pauseCompleter!.isCompleted,
    );
    session.resumeTest(pauseAfterEveryStep: true);
  }

  /// Advances through [count] paused steps sequentially.
  Future<void> advanceSteps(int count) async {
    for (var i = 0; i < count; i++) {
      await advanceOneStep();
    }
  }

  /// Waits until the test loop enters the post-body pause.
  Future<void> waitForPostBodyPause() async {
    await waitUntil(
      () =>
          session.postBodyCompleter != null &&
          !session.postBodyCompleter!.isCompleted,
    );
  }

  // -----------------------------------------------------------------------
  // Test 1: step_forward during post-body pause is a no-op
  // -----------------------------------------------------------------------
  test(
    'step_forward (resumeTest) during post-body pause does NOT end the test',
    () async {
      final loopFuture = runTestLoop(session, bodyWithSteps(2));

      // Advance through 2 steps.
      await advanceSteps(2);

      // Wait until the loop enters post-body pause.
      await waitForPostBodyPause();

      // Simulate step_forward (agent calls resumeTest) — should NOT resolve
      // postBodyCompleter because resumeTest only targets pauseCompleter.
      session.resumeTest(pauseAfterEveryStep: true);
      await pump();

      // The loop should still be waiting (postBodyCompleter not resolved).
      expect(session.postBodyCompleter, isNotNull);
      expect(session.postBodyCompleter!.isCompleted, isFalse);

      // Now disconnect to actually end the test.
      session.disconnect();
      await loopFuture;
    },
  );

  // -----------------------------------------------------------------------
  // Test 2: hot_reload during post-body pause re-enters body
  // -----------------------------------------------------------------------
  test('hot_reload during post-body pause re-enters the body', () async {
    var bodyCallCount = 0;
    var stepCount = 2;

    Future<void> body() async {
      bodyCallCount++;
      for (var i = 0; i < stepCount; i++) {
        await step(description: 'Step $i', action: () async {});
      }
    }

    final loopFuture = runTestLoop(session, body);

    // Advance through initial 2 steps.
    await advanceSteps(2);
    await waitForPostBodyPause();

    expect(bodyCallCount, 1);

    // Simulate hot reload with new steps.
    stepCount = 4;
    session.notifyHotReload();

    // Wait for the body to re-enter and the new steps to pause.
    // After hot reload, steps 0-1 are skipped, step 2 pauses.
    await waitUntil(() => bodyCallCount == 2);

    // Advance steps 2-3.
    await advanceSteps(2);
    await waitForPostBodyPause();

    // Disconnect to end.
    session.disconnect();
    await loopFuture;

    // Verify steps: 4 total, first 2 skipped, last 2 executed.
    final steps = session.registry.steps;
    expect(steps.length, 4);
    expect(session.completedStepCount, 4);
  });

  // -----------------------------------------------------------------------
  // Test 3: disconnect during post-body pause ends test
  // -----------------------------------------------------------------------
  test('disconnect during post-body pause ends the test', () async {
    final loopFuture = runTestLoop(session, bodyWithSteps(2));

    await advanceSteps(2);
    await waitForPostBodyPause();

    session.disconnect();

    // runTestLoop should return.
    await loopFuture;
    expect(session.agentDisconnected, isTrue);
  });

  // -----------------------------------------------------------------------
  // Test 4: THE RACE — step_forward BEFORE hot_reload (worst-case ordering)
  // -----------------------------------------------------------------------
  test('step_forward BEFORE hot_reload: '
      'new steps still execute, test does not end prematurely', () async {
    var stepCount = 2;

    Future<void> body() async {
      for (var i = 0; i < stepCount; i++) {
        await step(description: 'Step $i', action: () async {});
      }
    }

    final loopFuture = runTestLoop(session, body);

    // Advance through initial 2 steps.
    await advanceSteps(2);
    await waitForPostBodyPause();

    // WORST-CASE RACE: step_forward arrives BEFORE hot_reload.
    // This is the real production race condition — the agent sends
    // step_forward first (which calls resumeTest), then hot_reload
    // arrives a moment later. Without the postBodyCompleter fix,
    // resumeTest would resolve the post-body pause with `advance`,
    // ending the test prematurely before hot_reload can re-enter.
    stepCount = 5;
    session.resumeTest(pauseAfterEveryStep: true); // step_forward first!
    session.notifyHotReload(); // hot_reload second!

    // Body should re-enter. Steps 0-1 skipped, steps 2-4 need advancing.
    await advanceSteps(3);
    await waitForPostBodyPause();

    // All 5 steps complete.
    expect(session.completedStepCount, 5);

    session.disconnect();
    await loopFuture;
  });

  // -----------------------------------------------------------------------
  // Test 5: Step skipping after hot reload
  // -----------------------------------------------------------------------
  test('steps completed before hot reload are skipped on re-entry', () async {
    var stepCount = 2;

    Future<void> body() async {
      for (var i = 0; i < stepCount; i++) {
        await step(description: 'Step $i', action: () async {});
      }
    }

    final loopFuture = runTestLoop(session, body);

    await advanceSteps(2);
    await waitForPostBodyPause();

    // Hot reload with 5 steps.
    stepCount = 5;
    session.notifyHotReload();

    // Advance the 3 new steps.
    await advanceSteps(3);
    await waitForPostBodyPause();

    session.disconnect();
    await loopFuture;

    // After re-entry, registry was reset and rebuilt with 5 steps.
    // Steps 0-1 should have been marked as passed (skipped).
    final steps = session.registry.steps;
    expect(steps.length, 5);
    for (var i = 0; i < 2; i++) {
      expect(
        steps[i].status,
        StepStatus.passed,
        reason: 'Step $i should be skipped (passed)',
      );
    }
    for (var i = 2; i < 5; i++) {
      expect(
        steps[i].status,
        StepStatus.passed,
        reason: 'Step $i should have been executed',
      );
    }
  });

  // -----------------------------------------------------------------------
  // Test 6: HotReloadInterrupt mid-step pause
  // -----------------------------------------------------------------------
  test('hot reload while paused mid-step throws HotReloadInterrupt', () async {
    var bodyCallCount = 0;

    Future<void> body() async {
      bodyCallCount++;
      await step(description: 'Step 0', action: () async {});
      await step(description: 'Step 1', action: () async {});
    }

    final loopFuture = runTestLoop(session, body);

    // Advance step 0.
    await advanceOneStep();

    // Step 1 is now executing and paused (waiting for agent signal).
    await waitUntil(
      () =>
          session.pauseCompleter != null &&
          !session.pauseCompleter!.isCompleted,
    );
    expect(bodyCallCount, 1);

    // Hot reload while paused on step 1's pauseCompleter.
    session.notifyHotReload();

    // Body should re-enter.
    await waitUntil(() => bodyCallCount == 2);

    // On re-entry, step 0 is skipped, step 1 pauses again.
    await advanceOneStep();
    await waitForPostBodyPause();

    session.disconnect();
    await loopFuture;
  });
}
