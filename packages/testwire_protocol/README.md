# testwire_protocol

[![pub](https://img.shields.io/pub/v/testwire_protocol.svg)](https://pub.dev/packages/testwire_protocol)

Shared protocol types for the testwire ecosystem.

> **Testwire** is a step-based integration test runner for Flutter, controlled
> by an AI agent through MCP. This package defines the shared constants and
> types used internally. See the
> [full documentation](https://github.com/s-philippov/testwire_mcp) for
> getting started.

## Do I need this package?

You typically **don't** depend on it directly. All types are re-exported by the
[`testwire`](https://pub.dev/packages/testwire) package. For writing tests,
use [`testwire_flutter`](https://pub.dev/packages/testwire_flutter).

## What it defines

- **`TestwireExtension`** — VM service extension names.
- **`ExtensionResponse`** — standard response format for extensions.
- **`StepStatus`** — step lifecycle states (pending, running, passed, failed,
  fixed).
- **`TestStatus`** — overall test lifecycle states (waiting, running, paused,
  passed, failed).
