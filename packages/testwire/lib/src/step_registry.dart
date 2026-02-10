import 'dart:convert';

import 'package:testwire_protocol/testwire_protocol.dart'
    show StepStatus, TestStatus;

/// Represents the state of a single test step.
class StepState {
  StepState({
    required this.index,
    required this.description,
    this.context,
  });

  /// Zero-based index of this step in the test.
  final int index;

  /// Human-readable description of what this step does.
  final String description;

  /// Optional additional context for the agent (e.g. preconditions, hints).
  final String? context;

  /// Current status of this step.
  StepStatus status = StepStatus.pending;

  /// Error message if the step failed.
  String? error;

  /// Stack trace if the step failed.
  String? stackTrace;

  /// Serializes this step to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'index': index,
      'description': description,
      'status': status.name,
    };
    if (context != null) json['context'] = context;
    if (error != null) json['error'] = error;
    if (stackTrace != null) json['stackTrace'] = stackTrace;
    return json;
  }
}

/// Registry that tracks all steps in the current test run.
class StepRegistry {
  final List<StepState> _steps = [];

  /// All registered steps.
  List<StepState> get steps => List.unmodifiable(_steps);

  /// Overall test status derived from individual step statuses.
  TestStatus get testStatus {
    if (_steps.isEmpty) return TestStatus.waiting;
    if (_steps.any((s) => s.status == StepStatus.running)) {
      return TestStatus.running;
    }
    if (_steps.any((s) => s.status == StepStatus.failed)) {
      return TestStatus.failed;
    }
    if (_steps.every(
      (s) =>
          s.status == StepStatus.passed || s.status == StepStatus.fixed,
    )) {
      return TestStatus.passed;
    }
    // Some steps are still pending -- test is paused between steps.
    return TestStatus.paused;
  }

  /// Index of the step currently executing or last executed.
  int? get currentStepIndex {
    // Prefer running step, then last non-pending step.
    for (var i = _steps.length - 1; i >= 0; i--) {
      if (_steps[i].status != StepStatus.pending) return i;
    }
    return null;
  }

  /// Registers a new step and returns it.
  StepState addStep(String description, {String? context}) {
    final step = StepState(
      index: _steps.length,
      description: description,
      context: context,
    );
    _steps.add(step);
    return step;
  }

  /// Clears all steps (used on hot restart).
  void reset() {
    _steps.clear();
  }

  /// Serializes the full registry to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'status': testStatus.name,
      'currentStep': currentStepIndex,
      'steps': _steps.map((s) => s.toJson()).toList(),
    };
  }

  /// JSON-encodes the registry for use with `ServiceExtensionResponse.result()`.
  String toJsonString() => jsonEncode(toJson());
}
