# testwire_protocol

Shared protocol types for the testwire ecosystem.

Part of the [testwire](https://github.com/user/testwire) monorepo — see the
root README for full documentation and getting started guide.

## Purpose

Defines constants and types shared between the Flutter test side
([`testwire`](https://pub.dev/packages/testwire)) and the MCP server side
([`testwire_mcp`](https://pub.dev/packages/testwire_mcp)):

- **`TestwireExtension`** — VM service extension names.
- **`ExtensionResponse`** — standard response format for extensions.
- **`StepStatus`** — step lifecycle states (pending, running, passed, failed,
  fixed).
- **`TestStatus`** — overall test lifecycle states (waiting, running, paused,
  passed, failed).

## Do I need this package?

You typically **don't** depend on it directly. All types are re-exported by the
[`testwire`](https://pub.dev/packages/testwire) package.
