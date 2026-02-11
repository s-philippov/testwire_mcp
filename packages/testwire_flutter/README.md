# testwire_flutter

Flutter integration test wrapper for testwire with hot-reload support.

Part of the [testwire](https://github.com/user/testwire) monorepo — see the
root README for full documentation and getting started guide.

## APIs

### TestwireTest (class, recommended)

Extend `TestwireTest` and override `body()`. This gives you **full hot-reload
support** — edit steps, add new ones, hot-reload, and the test picks up changes
without restarting.

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
      action: () async {
        await tester.tap(find.byKey(const Key('action_button')));
        await tester.pumpAndSettle();
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
