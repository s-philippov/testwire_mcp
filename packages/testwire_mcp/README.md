# testwire_mcp

MCP server that bridges AI agents to Flutter integration tests via testwire.

Part of the [testwire](https://github.com/s-philippov/testwire_mcp) monorepo — see the
root README for full documentation and getting started guide.

## Installation

Globally:

```sh
dart pub global activate testwire_mcp
```

Or as a project dev dependency:

```sh
dart pub add dev:testwire_mcp
```

## Configuration

> The examples below use the global command `testwire_mcp`. If you installed
> it as a dev dependency, replace it with `dart run testwire_mcp`.

#### Cursor

[![Install MCP Server](https://cursor.com/deeplink/mcp-install-dark.svg)](cursor://anysphere.cursor-deeplink/mcp/install?name=testwire&config=eyJjb21tYW5kIjoidGVzdHdpcmVfbWNwIn0=)

Or manually add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "testwire": {
      "command": "testwire_mcp"
    }
  }
}
```

#### Claude Code

```sh
claude mcp add --transport stdio testwire -- testwire_mcp
```

#### Gemini CLI

Add to `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "testwire": {
      "command": "testwire_mcp"
    }
  }
}
```

#### Copilot

Add to `mcp.json`:

```json
{
  "servers": {
    "testwire": {
      "command": "testwire_mcp"
    }
  }
}
```

## Tools

| Tool | Description |
|------|-------------|
| `connect` | Connect to a Flutter test process via its VM service URI. |
| `disconnect` | Disconnect from the test process; optionally terminate the app. |
| `get_test_state` | Return all steps with their statuses and the overall test status. |
| `step_forward` | Execute the next step and pause. |
| `run_remaining` | Run all remaining steps; pause only on failure or completion. |
| `retry_step` | Re-execute the current failed step after a fix. |
| `hot_reload_testwire_test` | Hot-reload the test process and re-enter the test body. |
| `hot_restart_testwire_test` | Full hot restart (requires reconnecting). |
| `screenshot` | Capture screenshots of all active render views as base64 PNG images. |
