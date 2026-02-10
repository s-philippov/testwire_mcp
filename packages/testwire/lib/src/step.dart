import 'dart:async';

import 'package:testwire/src/agent.dart';
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
  final stepState = session.registry.addStep(description, context: context);

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

      if (!isAgentMode) {
        // CI mode: rethrow immediately, test fails.
        rethrow;
      }
    }

    // In agent mode: decide whether to pause.
    if (isAgentMode) {
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
        }
      }
    }
  }
}
