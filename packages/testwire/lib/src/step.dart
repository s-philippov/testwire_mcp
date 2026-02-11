import 'dart:async';

import 'package:testwire/src/hot_reload_interrupt.dart';
import 'package:testwire/src/session.dart';
import 'package:testwire_protocol/testwire_protocol.dart' show StepStatus;

/// Executes a single test step with agent-aware pause/resume logic.
///
/// In agent mode, the test pauses after each step (or only on failure,
/// depending on the mode set by the agent) and waits for the agent to
/// call `step_forward`, `run_remaining`, or `retry_step`.
///
/// In CI mode, steps execute sequentially without pausing.
///
/// When running inside [TestwireTest] or [testwireTest], steps that have
/// already completed in a previous body invocation are skipped automatically
/// after a hot reload (tracked by [TestSession.completedStepCount]).
///
/// Example:
/// ```dart
/// await step(
///   description: 'User sees welcome screen',
///   context: 'App launches with default locale; no login required.',
///   action: () async {
///     await tester.pumpAndSettle();
///     expect(find.text('Welcome'), findsOneWidget);
///   },
/// );
/// ```
Future<void> step({
  required String description,
  String? context,
  required Future<void> Function() action,
}) async {
  final session = activeSession;
  final stepIndex = session.registry.steps.length;
  final stepState = session.registry.addStep(description, context: context);

  // --- Skip already-completed steps after a hot-reload re-entry ------------
  if (stepIndex < session.completedStepCount) {
    stepState.status = StepStatus.passed;
    return;
  }

  // --- Check for pending hot reload before executing -----------------------
  if (session.hotReloadPending) {
    throw const HotReloadInterrupt();
  }

  var wasFailedBefore = false;
  var shouldRetry = true;

  while (shouldRetry) {
    shouldRetry = false;
    stepState.status = StepStatus.running;
    stepState.error = null;
    stepState.stackTrace = null;

    try {
      await action();
      // If this step previously failed and now passes, mark as fixed.
      stepState.status = wasFailedBefore ? StepStatus.fixed : StepStatus.passed;
    } catch (e, st) {
      stepState.status = StepStatus.failed;
      stepState.error = e.toString();
      stepState.stackTrace = st.toString();

      if (!session.agentMode) {
        // CI mode: rethrow immediately, test fails.
        rethrow;
      }
    }

    // In agent mode: decide whether to pause.
    if (session.agentMode) {
      final shouldPause =
          session.pauseAfterEveryStep || stepState.status == StepStatus.failed;

      if (shouldPause) {
        session.pauseCompleter = Completer<ResumeSignal>();
        final signal = await session.pauseCompleter!.future;
        session.pauseCompleter = null;

        switch (signal) {
          case ResumeSignal.retry:
            wasFailedBefore =
                wasFailedBefore || stepState.status == StepStatus.failed;
            shouldRetry = true;
          case ResumeSignal.advance:
            break;
          case ResumeSignal.hotReload:
            // Do NOT increment completedStepCount: the current step was
            // interrupted and should be re-executed after the body re-enters.
            throw const HotReloadInterrupt();
        }
      }
    }
  }

  // Track completion for hot-reload skip logic.
  session.completedStepCount = stepIndex + 1;
}
