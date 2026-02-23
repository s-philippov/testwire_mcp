# testwire

[![pub](https://img.shields.io/pub/v/testwire.svg)](https://pub.dev/packages/testwire)

Core step-based test execution framework for Flutter integration tests with
AI agent control.

> **Testwire** is a step-based integration test runner for Flutter, controlled
> by an AI agent through MCP. It lets an AI agent run, observe, debug, and
> modify Flutter integration tests in real time — with hot reload, step-by-step
> execution, and retry on failure.
>
> This package is the **core library** (pure Dart). Most Flutter developers
> should use
> [`testwire_flutter`](https://pub.dev/packages/testwire_flutter) instead —
> it wraps this package with `testWidgets` and hot-reload support. You also
> need [`testwire_mcp`](https://pub.dev/packages/testwire_mcp) to connect
> your AI agent. See the
> [full documentation](https://github.com/s-philippov/testwire_mcp) for
> getting started.

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
