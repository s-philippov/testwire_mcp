# Testwire Example — Agent Instructions

This is a Flutter feedback-form app used as a **testwire** demo.
Testwire lets an AI agent control Flutter integration tests step-by-step
through an MCP server — run steps, inspect results, fix failures,
hot-reload new code, and retry — all without restarting the test.

## Available tests

| File | Purpose |
|------|---------|
| `integration_test/app_test.dart` | Happy-path: submits a valid form (5 steps). Use as a style reference. |
| `integration_test/demo_fix_error_test.dart` | **Demo 1 — Fix Error Flow.** Contains a deliberate bug. |
| `integration_test/demo_incremental_test.dart` | **Demo 2 — Incremental Development Flow.** Starts with 1 step; rest are commented out. |

---

## Demo 1: Fix Error Flow

**File:** `integration_test/demo_fix_error_test.dart`

**What's being tested:** Your ability to detect a test failure, diagnose the
root cause, fix the code, and verify the fix — all while the test is running.

**The setup:** The test has 5 steps. Step 4 (Verify success screen) has a
**deliberate bug** — it expects `"3 stars from Alex"` but the test taps the
5th star, so the actual text is `"5 stars from Alex"`.

**What you must do:**

1. Connect to the running test (`connect` tool with the VM Service URI).
2. Run all steps (`run_remaining`) — they will run until one fails.
3. Check state (`get_test_state`) — step 4 should be `FAIL`.
4. Read the error message. It tells you the expected text was not found.
5. Open `demo_fix_error_test.dart` and find the bug on the line with
   `'3 stars from Alex'`. The test taps `star_5`, so the correct text is
   `'5 stars from Alex'`.
6. Fix the assertion.
7. Hot reload (`hot_reload_testwire_test`).
8. Retry the failed step (`retry_step`).
9. Check state (`get_test_state`) — step 4 should now be `PASS` or `FIXED`.
10. All steps are done. Report the final result to the user.
11. Disconnect (`disconnect`).

---

## Demo 2: Incremental Development Flow

**File:** `integration_test/demo_incremental_test.dart`

**What's being tested:** Your ability to add new test steps to a running test
via hot reload — simulating how a developer writes tests incrementally.

**The setup:** The test file has only 1 active step (Enter name). Four more
steps are commented out below the `TODO(agent)` marker.

**What you must do:**

1. Connect to the running test (`connect` tool with the VM Service URI).
2. Step forward (`step_forward`) to execute the only available step.
3. Check state (`get_test_state`) — step 0 should be `PASS`. The test is now
   paused with no more steps to run.
4. Open `demo_incremental_test.dart` and uncomment all 4 commented-out steps
   (the blocks after `// TODO(agent): Uncomment the steps below`).
5. Hot reload (`hot_reload_testwire_test`) to inject the new steps.
6. Run remaining steps (`run_remaining`).
7. Check state (`get_test_state`) — all 5 steps should be `PASS`.
8. Report the final result to the user.
9. Disconnect (`disconnect`).

---

## How to launch a test

Use `flutter run` (not `flutter test`) with agent mode enabled.

> **IMPORTANT:** Always run `flutter run` in the background (`block_until_ms: 0`
> or equivalent). The initial build takes 1-3 minutes and will **block your
> turn** if you wait for it synchronously. Instead, launch in the background,
> then poll the terminal output every few seconds until the VM Service URI
> appears.

```sh
cd example
flutter run \
  --dart-define=AGENT_MODE=true \
  -d <device_id> \
  integration_test/<test_file>.dart
```

The console will print a **VM Service URI** (e.g.
`ws://127.0.0.1:62957/abc=/ws`). Pass it to the `connect` MCP tool.

To list available devices: `flutter devices`.

## Key conventions

- Each test extends `TestwireTest` which handles agent connection and hot
  reload automatically.
- Every logical action is wrapped in `step(description: ..., context: ..., action: ...)`.
- Use `Key`-based finders (`find.byKey(const Key('...'))`) — see
  `lib/main.dart` for all widget keys.
- `registerTestwireExtensions()` is called once in `main()` — do not call it again.
- **Always use `hot_reload_testwire_test`** from the testwire MCP — not
  `hot_reload` from other MCP servers. Only the testwire tool notifies the
  test runner about the reload.
