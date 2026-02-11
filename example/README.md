# example

Example Flutter app with testwire demo integration tests.

Part of the [testwire](https://github.com/user/testwire) monorepo — see the
root README for full documentation and getting started guide.

## The app

A simple feedback form: name field, star rating, comment, and submit button.
On submission it shows a success screen with the rating summary.

## Integration tests

| File | Purpose |
|------|---------|
| `integration_test/app_test.dart` | Happy-path form submission (10 steps). |
| `integration_test/demo_fix_error_test.dart` | **Demo 1** — contains a deliberate bug for the agent to find and fix. |
| `integration_test/demo_incremental_test.dart` | **Demo 2** — starts with 1 step; agent uncomments the rest via hot reload. |

## Running

```sh
cd example
flutter run \
  --dart-define=AGENT_MODE=true \
  -d <device_id> \
  integration_test/<test_file>.dart
```

See [AGENTS.md](AGENTS.md) for detailed step-by-step instructions that an AI
agent should follow for each demo.
