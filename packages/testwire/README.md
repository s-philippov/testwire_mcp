# testwire

Core step-based test execution framework for Flutter integration tests with
AI agent control.

Part of the [testwire](https://github.com/user/testwire) monorepo — see the
root README for full documentation and getting started guide.

## What this package provides

- **`step()`** — declare a named, observable test step with a description,
  context, and action callback.
- **`TestSession`** / **`activeSession`** — per-test session state (step
  registry, pause control, agent mode flag).
- **`StepRegistry`** / **`StepState`** — tracks registered steps and their
  statuses (pending, running, passed, failed, fixed).
- **`registerTestwireExtensions()`** — registers VM service extensions that the
  MCP server calls to control the test.
- **`isAgentMode`** / **`waitForAgentConnection()`** — detect whether the test
  was launched with `--dart-define=AGENT_MODE=true` and pause until the agent
  connects.
- Re-exports from `testwire_protocol`: `StepStatus`, `TestStatus`,
  `TestwireExtension`, `ExtensionResponse`.

## Usage

This package is **pure Dart** and platform-independent. For Flutter integration
tests, use [`testwire_flutter`](https://pub.dev/packages/testwire_flutter)
which wraps this package with `testWidgets` and hot-reload support.

## Agent mode

When the test is launched with `--dart-define=AGENT_MODE=true`, `step()` calls
pause and wait for the agent to advance them. When `AGENT_MODE` is not set (or
`false`), all steps execute immediately — the test behaves like a normal
integration test.
