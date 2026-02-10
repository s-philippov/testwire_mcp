# Test Runner MCP: Step-Based Test Execution with Agent Control

> Design document for a lightweight test runner that gives an AI agent
> real-time visibility and control over integration test execution via MCP.

---

## Hot Reload Discovery

We experimentally verified that **hot reload works** inside integration tests
launched via `flutter run integration_test/<test>.dart`.

### Experiment Setup

1. Added a top-level function `_printProbe()` that prints a message
2. A keep-alive loop calls `_printProbe()` every 3 seconds
3. While the loop is running, changed the body of `_printProbe()` in the IDE
4. Sent `SIGUSR1` to the `flutter run` process (equivalent to pressing `r`)

### Results

| What was changed | Hot reload (`SIGUSR1`) | Hot restart (`SIGUSR2`) |
|---|---|---|
| Top-level `var` initializer | Library reloaded, but **value preserved** (expected — hot reload keeps state) | Value re-initialized |
| Method body (inline in running frame) | Library reloaded, but **old code continues executing** in the current stack frame | Code re-executed from scratch |
| **Separate function** called from the loop | **New function body picked up immediately** on next call | Code re-executed from scratch |

### Key Takeaway

Hot reload updates function definitions in memory. If the running loop calls an
external function, the next call will execute the updated code. This means the
agent can **modify test logic in real time** without recompiling:

```
Agent writes step function → hot reload → loop calls it → step executes
```

### Practical Implications

This changes the testing model fundamentally:

- **No recompilation** — hot reload takes ~200-500ms vs 2+ minutes for full build
- **Iterative test development** — agent writes one step, observes result,
  writes next step
- **Keep-alive + hot reload + Marionette MCP = interactive debug mode** without
  any additional libraries
- **`SIGUSR1`** triggers hot reload, **`SIGUSR2`** triggers hot restart
  (full test re-run)

### Limitations

- Hot reload does not re-initialize top-level / static variables
- Code already executing in the current stack frame is not updated — the change
  must be in a function that gets **called** from the running code
- `const` values are not updated by hot reload (use hot restart)

---

## Problem

When the agent runs an integration test today:

1. It launches the test blindly and waits for pass/fail
2. If the test fails, it has to hunt for the VM service URI via `lsof`/`ps`
3. It connects via Marionette MCP and sees the app state AFTER the failure —
   which may have changed since the actual moment of failure
4. It has no structured information about which step failed or why

The agent needs to be connected from the start and have step-level visibility
into test execution.

---

## Solution: Two Approaches

The hot reload discovery opens two complementary approaches.

### Approach A: Hot Reload Loop (lightweight, no library needed)

The agent holds the test in a keep-alive loop and incrementally writes test
steps as separate functions, hot-reloading them in:

```
Agent launches test via `flutter run integration_test/test.dart`
    │
    ▼
Test starts, fails quickly (or has a deliberate wait), enters keep-alive loop
    │
    ▼
Agent connects Marionette MCP — sees app state (screenshot, widget tree)
    │
    ▼
Agent writes `_step1()` function in the test file
Agent sends SIGUSR1 → hot reload
Keep-alive loop calls `_step1()` → step executes
    │
    ▼
Agent inspects result via Marionette MCP
Agent writes `_step2()`, hot reloads
    │
    ... repeats until test is complete ...
    │
    ▼
Agent restructures the test into final form
Agent sends SIGUSR2 → hot restart → full test runs end-to-end
```

**Pros:** Zero infrastructure, works today, no new libraries.
**Cons:** Requires custom loop logic in each test, no structured step metadata,
agent must manage the flow manually.

### Approach B: Step-Based Framework (structured, requires library)

A `step()` function wraps each test action with description, context, and
pause-on-failure semantics. A VM extension exposes step state. An MCP server
gives the agent a `getTestState` tool.

**Pros:** Structured step metadata, automatic pause on failure, agent sees
which step failed with description and context, works in CI mode too.
**Cons:** Requires building a library, more complexity.

### Recommendation

Start with **Approach A** for immediate productivity. Build **Approach B** when
the team writes enough tests that structured step metadata becomes valuable
(likely after 5-10 integration tests).

Approach B design follows below for future reference.

---

## Component 1: `step()` Function

Used inside integration tests to define structured steps:

```dart
await step(
  tester,
  description: 'Tap send button',
  context: 'send_button is only visible when chat_input is non-empty. '
           'See specs/components/chat_control_menu.md',
  action: () async {
    await tester.tap(find.byKey(const ValueKey('send_button')));
    await tester.pump();
  },
);
```

### Parameters

- **`description`** — human-readable step name, visible to the agent
- **`context`** (optional) — additional info for the agent: references to docs,
  known gotchas, visibility conditions
- **`action`** — the actual test logic (lambda)

### Behavior

- On success: marks step as `passed`, moves to next step
- On failure: marks step as `failed`, records the error, pauses test execution
  (keep-alive loop) so the agent can inspect the app state at the exact moment
  of failure via Marionette MCP

### Step Registry

All steps register themselves in a global list accessible via the VM extension:

```dart
class _StepState {
  final int index;
  final String description;
  final String? context;
  String status; // pending | running | passed | failed
  String? error;
}

final List<_StepState> _steps = [];
```

---

## Component 2: VM Extension

Registered via `dart:developer.registerExtension()` alongside Marionette
extensions:

```dart
developer.registerExtension(
  'ext.flutter.testRunner.getState',
  (method, params) async {
    return developer.ServiceExtensionResponse.result(
      json.encode({
        'status': _testStatus,        // running | passed | failed | waiting
        'currentStep': _currentStep,
        'steps': _steps.map((s) => {
          'index': s.index,
          'description': s.description,
          'context': s.context,
          'status': s.status,
          'error': s.error,
        }).toList(),
      }),
    );
  },
);
```

---

## Component 3: Test Runner MCP Server

A small MCP server (like Marionette MCP) that connects to the running test's
VM service and exposes one tool:

### `getTestState`

Returns the current test execution state:

```json
{
  "status": "failed",
  "currentStep": 3,
  "steps": [
    {
      "index": 1,
      "description": "Launch app and wait for welcome screen",
      "status": "passed"
    },
    {
      "index": 2,
      "description": "Tap 'Yes, continue'",
      "status": "passed"
    },
    {
      "index": 3,
      "description": "Tap send button",
      "context": "send_button is only visible when chat_input is non-empty. See specs/components/chat_control_menu.md",
      "status": "failed",
      "error": "Widget not found by key 'send_button'"
    },
    {
      "index": 4,
      "description": "Wait for Aurora response",
      "status": "pending"
    }
  ]
}
```

---

## Agent Workflow (Approach B)

```
Agent launches test
    │
    ▼
Test starts, registers VM extensions, waits for agent connection
(--dart-define=AGENT_MODE=true)
    │
    ▼
Agent connects Test Runner MCP + Marionette MCP
    │
    ▼
Agent signals connection → test begins executing steps
    │
    ├── Step 1: passed
    ├── Step 2: passed
    ├── Step 3: FAILED → test pauses
    │
    ▼
Agent calls getTestState → sees step 3 failed, reads description + context
Agent calls Marionette take_screenshots → sees the screen
Agent calls Marionette get_interactive_elements → sees widget tree
Agent inspects VM state if needed (providers, route stack, auth state)
    │
    ▼
Agent understands the problem, fixes the test, hot reloads, re-runs
```

---

## Two Modes

Controlled via `--dart-define=AGENT_MODE=true`:

### Agent Mode (development)

- Test waits for agent connection at the start (timeout: 60s, then starts
  without agent or exits with message)
- On step failure: pauses execution, keeps app alive
- Agent has full control via MCP

### CI Mode (default, `AGENT_MODE=false`)

- Steps execute sequentially without waiting
- On step failure: prints step description + error to stdout, exits with
  failure code
- No MCP interaction needed

---

## Interactive Debug Mode

The hot reload discovery enables a powerful debug workflow that can complement
step-based execution:

1. Agent launches a test that has a deliberate `_waitForAgent()` loop
2. Agent connects via Marionette MCP, explores the app state
3. Agent writes individual step functions, hot reloads them in
4. Each step runs, agent observes result via MCP screenshots/tree
5. When satisfied, agent refactors into a proper step-based test

This is useful for **test development and exploration** — the agent can interact
with the app iteratively, like a human developer pressing buttons in a debugger.

---

## Test Example

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerMarionetteExtensions();
  registerTestRunnerExtensions();

  testWidgets('Complete onboarding', (tester) async {
    if (agentMode) await waitForAgentConnection();

    final testOnError = FlutterError.onError;
    app.main();
    await tester.pump(const Duration(seconds: 2));
    FlutterError.onError = testOnError;

    await step(
      tester,
      description: 'App shows welcome screen',
      action: () async {
        await _pumpUntilFound(
          tester,
          find.text('Are you new here?'),
          timeout: const Duration(seconds: 30),
        );
      },
    );

    await step(
      tester,
      description: 'Tap "Yes, continue" to start onboarding',
      action: () async {
        await tester.tap(find.text('Yes, continue'));
        await tester.pump(const Duration(seconds: 2));
      },
    );

    await step(
      tester,
      description: 'Select theme',
      context: 'Theme carousel with "Use Sunset", "Use Ocean", etc. '
               'Default selection is Sunset.',
      action: () async {
        await _pumpUntilFound(
          tester,
          find.textContaining('Use '),
          timeout: const Duration(seconds: 10),
        );
        await tester.tap(find.textContaining('Use '));
        await tester.pump(const Duration(seconds: 2));
      },
    );

    await step(
      tester,
      description: 'Enter name and tap "Let\'s start"',
      context: 'Name field has autofocus. No ValueKey — use find.byType(TextField).',
      action: () async {
        await _pumpUntilFound(
          tester,
          find.byType(TextField),
          timeout: const Duration(seconds: 10),
        );
        await tester.enterText(find.byType(TextField), 'Test User');
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text("Let's start"));
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
```

---

## Relation to Patrol

Patrol (`patrol` package) handles native OS dialogs (permissions, notifications)
that are outside Flutter's widget tree. It complements this approach:

- **Test Runner MCP** — manages test step execution and agent communication
- **Marionette MCP** — interacts with Flutter widgets (screenshots, taps, tree)
- **Patrol** — handles native platform dialogs (grant permission, dismiss notification)

All three can be used together in the same integration test.

---

## Package Structure (future)

This could be packaged as a standalone library:

```
test_runner_mcp/
  lib/
    src/
      step.dart              # step() function + StepState registry
      extensions.dart        # VM extension registration
      wait_for_agent.dart    # waitForAgentConnection()
    test_runner_mcp.dart     # public API
  bin/
    test_runner_mcp.dart     # MCP server binary
```

For now, implement as helpers inside the project. Extract to a package when
the API stabilizes.
