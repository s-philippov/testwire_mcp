import 'dart:async';

import 'package:testwire/src/session.dart';

/// Whether the test is running in agent mode.
///
/// Detected via `--dart-define=AGENT_MODE=true` at build/test time.
/// In agent mode, steps pause after execution so the AI agent can inspect
/// state and control the test flow.
///
/// In CI mode (default), steps run sequentially without pausing.
const bool isAgentMode = bool.fromEnvironment('AGENT_MODE');

/// Blocks until the agent calls `stepForward`, `runRemaining`, or
/// `disconnect`, which internally signal agent connection.
///
/// Creates a fresh [TestSession] each time, so all state from the previous
/// test is discarded.  Safe to call once per `testWidgets` body.
///
/// In CI mode (`isAgentMode == false`), still creates a session (for the
/// step registry) but returns immediately without waiting.
///
/// There is no timeout — the test waits indefinitely for the agent.
/// If the agent sends a `disconnect` signal, the test proceeds without
/// pausing, as if running in CI mode.
Future<void> waitForAgentConnection() async {
  final session = startSession();

  if (!isAgentMode) {
    return;
  }

  session.agentCompleter = Completer<void>();
  await session.agentCompleter!.future;
}
