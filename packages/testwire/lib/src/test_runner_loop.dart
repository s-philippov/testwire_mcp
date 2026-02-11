import 'dart:async';

import 'package:testwire/src/hot_reload_interrupt.dart';
import 'package:testwire/src/session.dart';

/// Runs the core hot-reload-aware test loop.
///
/// This is the engine that powers `testwireTest`.  It is extracted here as a
/// pure-Dart function (no Flutter imports) so it can be unit-tested without
/// a widget test harness.
///
/// [session] – the active [TestSession] for this test run.
/// [body]    – the test body containing `step()` calls.
///
/// The loop:
///  1. Resets the step registry (but preserves [TestSession.completedStepCount]
///     so already-executed steps are skipped).
///  2. Calls [body].
///  3. If [body] throws [HotReloadInterrupt], re-enters the loop immediately.
///  4. If the session is in agent mode and the agent has not disconnected,
///     enters a **post-body pause** using [TestSession.postBodyCompleter].
///     This keeps the test alive so the agent can hot-reload new steps or
///     signal completion.
///  5. If the agent hot-reloads during the post-body pause, loops back to (1).
///  6. If the agent disconnects (or the session is not in agent mode), breaks.
Future<void> runTestLoop(
  TestSession session,
  Future<void> Function() body,
) async {
  while (true) {
    // Clear registry for re-run (step indices start from 0 again)
    // but do NOT reset completedStepCount – that enables skipping.
    session.registry.reset();

    try {
      await body();

      // Body completed normally – all current steps done.
      if (session.hotReloadPending) {
        // A hot reload arrived while body was finishing.
        session.hotReloadPending = false;
        continue;
      }

      // In agent mode: don't finish the test yet. Wait for the agent
      // to either hot-reload new steps or signal completion
      // (disconnect). Without this pause the test would end
      // immediately, leaving no window for hot reload.
      if (session.agentMode && !session.agentDisconnected) {
        session.postBodyCompleter = Completer<ResumeSignal>();
        final signal = await session.postBodyCompleter!.future;
        session.postBodyCompleter = null;

        if (signal == ResumeSignal.hotReload) {
          session.hotReloadPending = false;
          continue; // Re-call body with new steps.
        }
        // disconnect -> fall through to break.
      }

      break; // Test finished.
    } on HotReloadInterrupt {
      // step() threw because a hot reload happened while paused.
      session.hotReloadPending = false;
      continue; // Re-call body with the new function definition.
    }
  }
}
