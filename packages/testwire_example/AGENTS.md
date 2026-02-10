# Testwire Example — Agent Instructions

This is a Flutter feedback-form app used as a testwire demo.
An existing test (`integration_test/app_test.dart`) covers the happy path —
submitting a valid form. Use it as a reference for style and conventions.

## Your task

Write a **new** `testWidgets` in the same test file for the test case below.

### Test case: Form validation blocks empty submission

**Preconditions:** App is launched, feedback form is visible.

| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Tap **Submit** without filling in any fields | Error text "Name is required" appears under the name field. Error text "Please select a rating" appears below the star row. The form stays visible (no success screen). |
| 2 | Enter a name and select a rating (any), then tap **Submit** again | Success screen appears with "Thank you for your feedback!" message. |

## How to run

Use the **testwire MCP** to control test execution.
The MCP tool descriptions explain everything: how steps work, what statuses
mean, and how to advance or retry.

```sh
cd packages/testwire_example
flutter test integration_test/app_test.dart --dart-define=AGENT_MODE=true
```

## Key conventions

- Each `testWidgets` must call `waitForAgentConnection()` first.
- Wrap every logical action in `step(description: ..., context: ..., action: ...)`.
- Use `Key`-based finders (`find.byKey(const Key('...'))`) — see `lib/main.dart` for all available keys.
- `registerTestwireExtensions()` is already called once in `main()` — do not call it again.
