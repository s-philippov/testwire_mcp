import 'dart:convert';

/// A response returned by a testwire VM service extension.
///
/// Every success response carries [status] `'ok'` plus optional
/// action-specific fields ([mode], [action]).
///
/// Use the named constructors for the three standard responses, or
/// [ExtensionResponse.fromMap] to parse a response received over the
/// VM service wire.
class ExtensionResponse {
  const ExtensionResponse._({
    required this.status,
    this.mode,
    this.action,
  });

  // -- Standard responses --------------------------------------------------

  /// Response for [TestwireExtension.stepForward].
  static const stepForward = ExtensionResponse._(
    status: 'ok',
    mode: 'step',
  );

  /// Response for [TestwireExtension.runRemaining].
  static const runRemaining = ExtensionResponse._(
    status: 'ok',
    mode: 'auto',
  );

  /// Response for [TestwireExtension.retry].
  static const retry = ExtensionResponse._(
    status: 'ok',
    action: 'retry',
  );

  /// Response for [TestwireExtension.disconnect].
  static const disconnect = ExtensionResponse._(
    status: 'ok',
    action: 'disconnect',
  );

  // -- Fields --------------------------------------------------------------

  /// `'ok'` on success; other values (e.g. `'Error'`) indicate failure.
  final String status;

  /// Execution mode: `'step'` (step-by-step) or `'auto'` (run remaining).
  ///
  /// Present in [stepForward] and [runRemaining] responses.
  final String? mode;

  /// Action identifier (e.g. `'retry'`).
  ///
  /// Present in [retry] responses.
  final String? action;

  // -- Serialisation -------------------------------------------------------

  /// Constructs an [ExtensionResponse] from a raw VM service response map.
  factory ExtensionResponse.fromMap(Map<String, dynamic> map) {
    return ExtensionResponse._(
      status: map['status'] as String? ?? 'unknown',
      mode: map['mode'] as String?,
      action: map['action'] as String?,
    );
  }

  /// Returns a JSON-compatible map.
  Map<String, String> toMap() => {
    'status': status,
    'mode': ?mode,
    'action': ?action,
  };

  /// JSON-encodes [toMap] for `ServiceExtensionResponse.result()`.
  String encode() => jsonEncode(toMap());
}
