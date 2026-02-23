# testwire_flutter

[![pub](https://img.shields.io/pub/v/testwire_flutter.svg)](https://pub.dev/packages/testwire_flutter)

Flutter integration test wrapper for testwire with hot-reload support.

> **Testwire** is a step-based integration test runner for Flutter, controlled
> by an AI agent through MCP. It lets an AI agent run, observe, debug, and
> modify Flutter integration tests in real time — with hot reload, step-by-step
> execution, and retry on failure.
>
> This is the **main package for writing tests**. It pulls in
> [`testwire`](https://pub.dev/packages/testwire) and
> [`testwire_protocol`](https://pub.dev/packages/testwire_protocol)
> automatically. You also need
> [`testwire_mcp`](https://pub.dev/packages/testwire_mcp) to connect your
> AI agent. See the
> [full documentation](https://github.com/s-philippov/testwire_mcp) for the
> complete getting started guide.

## Why?

Without Testwire, every test failure means rebuilding, redeploying, and
re-running from scratch — slow and expensive in tokens. With Testwire the agent
gets structured per-step feedback, fixes code via hot reload, and retries just
the failed step. No restarts. Same test works in CI without the agent.

## Quick start

### 1. Add dependencies

```yaml
# pubspec.yaml
dev_dependencies:
  testwire_flutter: ^0.1.3
  integration_test:
    sdk: flutter
```

### 2. Install the MCP server

```sh
dart pub global activate testwire_mcp
```

### 3. Write a test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testwire_flutter/testwire_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testwire/testwire.dart';
import 'package:my_app/main.dart' as app;

class MyTest extends TestwireTest {
  MyTest()
      : super(
          'My test',
          setUp: (tester) async {
            app.main();
            await tester.pumpAndSettle();
          },
        );

  @override
  Future<void> body(WidgetTester tester) async {
    await step(
      description: 'Tap the button',
      context: 'Tap the main action button.',
      action: () async {
        await tester.tap(find.byKey(const Key('action_button')));
        await tester.pumpAndSettle();
      },
    );

    await step(
      description: 'Verify result',
      context: 'Check that the result text is displayed.',
      action: () async {
        expect(find.text('Done!'), findsOneWidget);
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerTestwireExtensions();
  MyTest().run();
}
```

### 4. Run the test

```sh
flutter run \
  --dart-define=AGENT_MODE=true \
  -d <device_id> \
  integration_test/my_test.dart
```

The console prints a VM Service URI. The agent uses it to connect via the
`connect` MCP tool, then drives the test with `step_forward`,
`run_remaining`, `get_test_state`, etc.

## APIs

### TestwireTest (class, recommended)

Extend `TestwireTest` and override `body()`. This gives you **full hot-reload
support** — edit steps, add new ones, hot-reload, and the test picks up changes
without restarting.

### testwireTest (function, simpler)

A `testWidgets` wrapper for tests that don't need hot-reload for the test body
(e.g. CI-only tests).

```dart
testwireTest(
  'My test',
  (tester) async {
    await step(
      description: 'Verify welcome',
      action: () async {
        expect(find.text('Welcome'), findsOneWidget);
      },
    );
  },
  setUp: (tester) async {
    app.main();
    await tester.pumpAndSettle();
  },
);
```

## Hot reload

`TestwireTest` supports hot reload because `body()` is resolved via **virtual
dispatch** — after a reload the Dart VM patches the method implementation, and
the next call executes the updated code.

`testwireTest()` captures the body as an anonymous closure, which is
instantiated once and **not updated** by hot reload. Use it when hot-reload of
the test body is not needed.

## Without agent mode

When `AGENT_MODE` is not set (or `false`), all `step()` calls execute
immediately without pausing — the test runs like a normal integration test.
This means the same test file works for both agent-controlled and CI
environments.
