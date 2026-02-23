# testwire_device — host-side device control

## Idea

A standalone package (pure Dart CLI/library, not a Flutter plugin) that runs
**on the host machine** and controls a connected device or emulator via `adb`
(Android) and `xcrun simctl` (iOS Simulator). Framework-agnostic — does not
depend on testwire or any other test framework.

The key design choice: instead of running native code on the device (which
requires a separate test runner and breaks `flutter run` / hot reload),
testwire_device operates **from the host** through standard platform tools.
Simpler, no native code required, no changes to the test launch flow — but
covers fewer scenarios than on-device approaches.

## Capabilities

### Permissions (pre-grant / revoke)

```dart
final device = TestwireDevice.android(deviceId: 'emulator-5554');

// Grant permission before the dialog appears
await device.grantPermission('com.example.app', Permission.camera);
await device.grantPermission('com.example.app', Permission.location);

// Revoke
await device.revokePermission('com.example.app', Permission.camera);

// Reset all
await device.resetPermissions('com.example.app');
```

```dart
final device = TestwireDevice.iosSimulator();

// iOS Simulator — via xcrun simctl privacy
await device.grantPermission('com.example.app', Permission.camera);
await device.revokePermission('com.example.app', Permission.camera);
await device.resetPermissions('com.example.app');
```

### Under the hood

Android:
```
adb shell pm grant <package> android.permission.CAMERA
adb shell pm revoke <package> android.permission.CAMERA
adb shell pm reset-permissions <package>
```

iOS Simulator:
```
xcrun simctl privacy booted grant camera <bundle-id>
xcrun simctl privacy booted revoke camera <bundle-id>
xcrun simctl privacy booted reset all <bundle-id>
```

### Future capabilities (v2+)

- System settings (WiFi, Bluetooth, Airplane mode, Dark mode)
- App install / uninstall
- Device-level screenshots (not just Flutter UI)
- Text input via adb input / simctl
- Mock location
- Push notifications (simctl on iOS)
- Deep links (adb shell am start / xcrun simctl openurl)

## Architecture

```
testwire_device/
├── lib/
│   ├── testwire_device.dart          # public API
│   └── src/
│       ├── device.dart               # abstract TestwireDevice interface
│       ├── android_device.dart       # implementation via adb
│       ├── ios_simulator_device.dart  # implementation via xcrun simctl
│       ├── permission.dart           # Permission enum with platform string mappings
│       └── process_runner.dart       # Process.run wrapper for testability
├── bin/
│   └── testwire_device.dart          # CLI: testwire_device grant-permission --app com.example --permission camera
└── pubspec.yaml                      # pure Dart, no Flutter SDK dependency
```

## Integration

### With testwire (in tests, on CI without MCP)

```dart
class MyTest extends TestwireTest {
  final device = TestwireDevice.autoDetect(); // detects platform

  @override
  Future<void> body(WidgetTester tester) async {
    // Grant permission BEFORE the app requests it
    await device.grantPermission(appId, Permission.camera);

    await step('Open camera screen', () async {
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      // No dialog — permission already granted
    });
  }
}
```

### With testwire_mcp (MCP tool for AI agents)

testwire_mcp exposes MCP tools that delegate to testwire_device:

```
MCP tool: grant_permission(app_id, permission)
    → TestwireDevice.grantPermission(appId, permission)
        → Process.run('adb', ['shell', 'pm', 'grant', ...])
```

### As CLI (in CI pipelines)

```bash
# Grant permissions before running tests
dart run testwire_device grant-permission \
  --app com.example.app \
  --permission camera,location,microphone

# Run tests as usual
flutter test integration_test/
```

## Why a separate package

1. **Framework-agnostic** — works with any test framework (integration_test, flutter_test, etc.)
2. **No Flutter SDK dependency** — pure Dart, uses dart:io Process
3. **Works as both library and CLI** — from tests, from MCP, from CI scripts
4. **Preserves flutter run** — no native code in the app, no changes to the launch flow

## Limitations

- **Real iOS devices**: `xcrun simctl` only works with simulators. Pre-granting permissions on real iOS devices is not possible without XCUITest running on-device
- **Cannot test the dialog itself**: pre-granting means the dialog never appears — if you need to test the dialog UI or a "user denied" scenario, this approach does not apply
- **Requires platform tools on host**: adb (Android SDK) or Xcode (iOS) must be installed on the host machine

## Android implementation notes

Flutter integration_test on Android runs through the Android Instrumentation
Runner (AndroidJUnitRunner). While `testInstrumentationRunnerArguments` in
Gradle can statically pre-grant permissions, it is not suitable for dynamic
grant/revoke during test execution. `adb shell pm grant/revoke` is more
flexible and works at runtime.
