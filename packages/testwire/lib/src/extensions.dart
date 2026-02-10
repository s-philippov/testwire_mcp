import 'dart:developer' as developer;

import 'package:testwire_protocol/testwire_protocol.dart'
    show ExtensionResponse, TestwireExtension;
import 'package:testwire/src/session.dart';

bool _extensionsRegistered = false;

/// Registers all testwire VM service extensions.
///
/// Safe to call multiple times -- extensions are registered only once per
/// isolate (subsequent calls are no-ops).  Typically called in `setUpAll`:
///
/// ```dart
/// setUpAll(registerTestwireExtensions);
/// ```
///
/// Extension callbacks read [activeSession] at call time, so they always
/// operate on whichever test is currently running.
///
/// Registers:
/// - [TestwireExtension.getState] -- returns full test state JSON
/// - [TestwireExtension.stepForward] -- start or advance one step
/// - [TestwireExtension.runRemaining] -- start or run all remaining steps
/// - [TestwireExtension.retry] -- retry the current failed step
void registerTestwireExtensions() {
  if (_extensionsRegistered) return;
  _extensionsRegistered = true;

  developer.registerExtension(
    TestwireExtension.getState.method,
    (method, parameters) async {
      return developer.ServiceExtensionResponse.result(
        activeSession.registry.toJsonString(),
      );
    },
  );

  developer.registerExtension(
    TestwireExtension.stepForward.method,
    (method, parameters) async {
      activeSession.resumeTest(pauseAfterEveryStep: true);
      return developer.ServiceExtensionResponse.result(
        ExtensionResponse.stepForward.encode(),
      );
    },
  );

  developer.registerExtension(
    TestwireExtension.runRemaining.method,
    (method, parameters) async {
      activeSession.resumeTest(pauseAfterEveryStep: false);
      return developer.ServiceExtensionResponse.result(
        ExtensionResponse.runRemaining.encode(),
      );
    },
  );

  developer.registerExtension(
    TestwireExtension.retry.method,
    (method, parameters) async {
      activeSession.retryCurrentStep();
      return developer.ServiceExtensionResponse.result(
        ExtensionResponse.retry.encode(),
      );
    },
  );

  developer.registerExtension(
    TestwireExtension.disconnect.method,
    (method, parameters) async {
      activeSession.disconnect();
      return developer.ServiceExtensionResponse.result(
        ExtensionResponse.disconnect.encode(),
      );
    },
  );
}
