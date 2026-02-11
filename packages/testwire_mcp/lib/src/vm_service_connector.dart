import 'dart:async';

import 'package:logging/logging.dart' as logging;
import 'package:testwire_protocol/testwire_protocol.dart'
    show TestwireExtension;
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Exception thrown when an operation is attempted without an active connection.
class NotConnectedException implements Exception {
  const NotConnectedException();

  @override
  String toString() =>
      'Not connected to any app. Use the connect tool first with the VM service URI.';
}

/// Exception thrown when a VM service extension call fails.
class VmServiceExtensionException implements Exception {
  VmServiceExtensionException(this.message, this.error, this.stackTrace);

  final String message;
  final String? error;
  final String? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write('\nError: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nStack trace: $stackTrace');
    }
    return buffer.toString();
  }
}

/// Manages connection to a Flutter test process VM service and provides
/// methods for calling testwire VM extensions.
class VmServiceConnector {
  VmServiceConnector() : _logger = logging.Logger('VmServiceConnector');

  final logging.Logger _logger;
  VmService? _service;
  String? _isolateId;
  StreamSubscription<Event>? _serviceEventSubscription;

  final Map<String, String?> _registeredServices = {};
  final Map<String, List<Completer<String?>>> _pendingServiceRequests = {};

  /// Returns true if currently connected to a VM service.
  bool get isConnected => _service != null && _isolateId != null;

  /// Connects to a VM service at the given [uri].
  ///
  /// Finds the isolate with testwire extensions. Does NOT signal the test
  /// to start -- that is done when [stepForward] or [runRemaining] is called.
  Future<void> connect(String uri) async {
    if (isConnected) {
      _logger.warning('Already connected, disconnecting first');
      await disconnect();
    }

    _logger.info('Connecting to VM service at $uri');

    try {
      _service = await vmServiceConnectUri(uri);
      _serviceEventSubscription = _service!.onServiceEvent.listen((e) {
        switch (e.kind) {
          case EventKind.kServiceRegistered:
            final serviceName = e.service!;
            _registeredServices[serviceName] = e.method;
            _logger.info('Service registered: $serviceName -> ${e.method}');
            if (_pendingServiceRequests.containsKey(serviceName)) {
              for (final completer in _pendingServiceRequests[serviceName]!) {
                completer.complete(e.method);
              }
              _pendingServiceRequests.remove(serviceName);
            }
          case EventKind.kServiceUnregistered:
            _registeredServices.remove(e.service!);
            _logger.info('Service unregistered: ${e.service}');
          default:
            _logger.fine('Service event: ${e.kind}');
        }
      });
      await _service!.streamListen(EventStreams.kService);

      _isolateId = await _findIsolateWithTestwireExtensions();
      _logger.info('Connected to isolate: $_isolateId');
    } catch (err) {
      _service = null;
      _isolateId = null;
      _logger.severe('Failed to connect to VM service', err);
      rethrow;
    }
  }

  /// Signals the test that the agent is disconnecting, waits for it to
  /// finish, then terminates the application process and drops the
  /// VM service connection.
  ///
  /// The test will run all remaining steps without pausing, as if
  /// `run_remaining` was called.  After the test completes the Flutter
  /// application is exited so that the `flutter run` process terminates
  /// cleanly.  If any signal fails (e.g. the isolate already exited),
  /// the connection is dropped silently.
  Future<void> disconnect({bool terminateApp = true}) async {
    if (_service != null) {
      _logger.info('Disconnecting from VM service');

      // Best-effort: tell the test to finish on its own.
      try {
        if (_isolateId != null) {
          await _callExtension(TestwireExtension.disconnect.method);
          _logger.fine('Disconnect signal sent to test');
        }
      } catch (err) {
        _logger.fine('Could not signal disconnect (test may have ended): $err');
      }

      if (terminateApp) {
        // Give the test a moment to complete before killing the app.
        await Future<void>.delayed(const Duration(seconds: 2));

        // Terminate the Flutter application so `flutter run` exits.
        // The app may exit before responding, so use a short timeout.
        try {
          final exitMethod =
              _registeredServices['flutterExit'] ?? 's0.flutterExit';
          await _service!
              .callMethod(exitMethod)
              .timeout(const Duration(seconds: 3));
          _logger.fine('App exit signal sent');
        } catch (err) {
          _logger.fine('Could not exit app (may have already exited): $err');
        }
      }

      await _serviceEventSubscription?.cancel();
      _serviceEventSubscription = null;
      try {
        await _service!.dispose().timeout(const Duration(seconds: 2));
      } catch (_) {}
      _service = null;
      _isolateId = null;
      _registeredServices.clear();
      _pendingServiceRequests.clear();
      _logger.fine('Disconnected');
    }
  }

  /// Returns a future that completes with the registered method name for the
  /// given [serviceName].
  ///
  /// If the service is already registered, returns immediately.
  /// Otherwise, waits up to [timeout] for the service to be registered.
  /// Returns `null` if the service is not registered within the timeout.
  Future<String?> waitForServiceRegistration(
    String serviceName, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    if (_registeredServices.containsKey(serviceName)) {
      return _registeredServices[serviceName];
    }

    final completer = Completer<String?>();
    _pendingServiceRequests.putIfAbsent(serviceName, () => []).add(completer);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingServiceRequests[serviceName]?.remove(completer);
        if (_pendingServiceRequests[serviceName]?.isEmpty ?? false) {
          _pendingServiceRequests.remove(serviceName);
        }
        return null;
      },
    );
  }

  void _ensureConnected() {
    if (!isConnected) {
      throw const NotConnectedException();
    }
  }

  /// Calls a testwire VM service extension and returns the response.
  Future<Map<String, dynamic>> _callExtension(
    String extensionName, [
    Map<String, dynamic>? args,
  ]) async {
    _ensureConnected();

    _logger.fine('Calling extension: $extensionName');

    try {
      final response = await _service!.callServiceExtension(
        extensionName,
        isolateId: _isolateId,
        args: args,
      );

      final responseJson = response.json;
      if (responseJson == null) {
        throw VmServiceExtensionException(
          'Extension $extensionName returned null response',
          null,
          null,
        );
      }

      _logger.finest('Extension response: $responseJson');

      if (responseJson['status'] == 'Error') {
        throw VmServiceExtensionException(
          'Extension $extensionName failed',
          responseJson['error'] as String?,
          responseJson['stackTrace'] as String?,
        );
      }

      return responseJson;
    } catch (err) {
      _logger.severe('Error calling extension $extensionName', err);
      rethrow;
    }
  }

  /// Gets the full test state from the testwire test process.
  Future<Map<String, dynamic>> getTestState() {
    return _callExtension(TestwireExtension.getState.method);
  }

  /// Signals the test to advance one step (step-by-step mode).
  ///
  /// If the test has not started yet, this also signals agent connection.
  Future<Map<String, dynamic>> stepForward() {
    return _callExtension(TestwireExtension.stepForward.method);
  }

  /// Signals the test to run all remaining steps (auto mode).
  ///
  /// If the test has not started yet, this also signals agent connection.
  Future<Map<String, dynamic>> runRemaining() {
    return _callExtension(TestwireExtension.runRemaining.method);
  }

  /// Signals the test to retry the current (failed) step.
  Future<Map<String, dynamic>> retryStep() {
    return _callExtension(TestwireExtension.retry.method);
  }

  /// Captures screenshots of all active render views in the Flutter app.
  ///
  /// Returns a list of base64-encoded PNG strings, one per render view.
  Future<List<String>> takeScreenshots() async {
    final result = await _callExtension(TestwireExtension.screenshot.method);
    final screenshots = result['screenshots'];
    if (screenshots is List) {
      return screenshots.cast<String>();
    }
    return const [];
  }

  /// Performs a hot reload of the Flutter app.
  ///
  /// Returns `true` if reload was successful.
  Future<bool> hotReload() async {
    _ensureConnected();

    _logger.info('Performing hot reload');

    try {
      final method = await waitForServiceRegistration(
        'reloadSources',
        timeout: const Duration(seconds: 5),
      );
      bool success;
      if (method != null) {
        _logger.fine('Using registered service method: $method');
        final result = await _service!.callMethod(
          method,
          isolateId: _isolateId!,
        );
        _logger.fine('Hot reload completed: result=${result.json}');
        success = result.json?['type'] == 'Success';
      } else {
        _logger.fine('No registered service, falling back to reloadSources');
        final report = await _service!.reloadSources(_isolateId!);
        _logger.fine('Hot reload completed: success=${report.success}');
        success = report.success ?? false;
      }

      // Notify the test process so it can re-enter the body with new code.
      if (success) {
        try {
          await _callExtension(TestwireExtension.notifyHotReload.method);
          _logger.info('Hot reload notification sent to test');
        } catch (err) {
          _logger.warning('Failed to notify test of hot reload: $err');
        }
      }

      return success;
    } catch (err) {
      _logger.severe('Hot reload failed', err);
      rethrow;
    }
  }

  /// Performs a full hot restart of the Flutter app.
  ///
  /// After restart the test process re-initializes from scratch.
  /// The agent must call [connect] again.
  Future<void> hotRestart() async {
    _ensureConnected();

    _logger.info('Performing hot restart');

    try {
      final method = await waitForServiceRegistration('hotRestart');
      if (method == null) {
        // Fallback: use the VM service method directly.
        // Note: hotRestart may cause the isolate to be replaced,
        // so we disconnect after triggering it.
        await _service!.callMethod('hotRestart', isolateId: _isolateId!);
      } else {
        await _service!.callMethod(method, isolateId: _isolateId!);
      }
      _logger.fine('Hot restart triggered');
    } catch (err) {
      // Hot restart may cause the connection to drop, which is expected.
      _logger.fine('Hot restart completed (connection may have dropped): $err');
    } finally {
      // Always disconnect after hot restart since the isolate is gone.
      await disconnect();
    }
  }

  /// Finds the first isolate that has the testwire extensions.
  Future<String> _findIsolateWithTestwireExtensions() async {
    final vm = await _service!.getVM();
    if (vm.isolates == null || vm.isolates!.isEmpty) {
      throw Exception('No isolates found in the VM');
    }

    for (final isolateRef in vm.isolates!) {
      if (isolateRef.id == null) continue;

      try {
        final isolate = await _service!.getIsolate(isolateRef.id!);
        final hasExtension =
            isolate.extensionRPCs?.any(
              (ext) => ext == TestwireExtension.getState.method,
            ) ??
            false;

        if (hasExtension) {
          return isolateRef.id!;
        }
      } catch (err) {
        _logger.warning(
          'Failed to check extensions for isolate ${isolateRef.id}',
          err,
        );
        continue;
      }
    }

    throw Exception(
      'No isolate found with ${TestwireExtension.getState.method} extension. '
      'Make sure the Flutter test has called registerTestwireExtensions().',
    );
  }
}
