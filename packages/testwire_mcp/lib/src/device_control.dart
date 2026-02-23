import 'dart:io';

import 'package:logging/logging.dart' as logging;

/// Grants all runtime permissions for an app on the connected device/simulator.
///
/// Detects the platform automatically based on which tools are available
/// (`adb` for Android, `xcrun` for iOS Simulator).
class DeviceControl {
  DeviceControl() : _logger = logging.Logger('DeviceControl');

  final logging.Logger _logger;

  /// Grants all permissions for [appId] on the connected device/simulator.
  ///
  /// Returns a human-readable summary of what was done.
  Future<String> grantAllPermissions(String appId) async {
    final platform = await _detectPlatform();

    return switch (platform) {
      _Platform.android => _grantAllAndroid(appId),
      _Platform.iosSimulator => _grantAllIosSimulator(appId),
      _Platform.none => throw StateError(
          'No supported device tools found. '
          'Ensure adb (Android) or xcrun (iOS Simulator) is available on PATH.',
        ),
    };
  }

  /// Revokes all permissions for [appId] on the connected device/simulator.
  ///
  /// Returns a human-readable summary of what was done.
  Future<String> revokeAllPermissions(String appId) async {
    final platform = await _detectPlatform();

    return switch (platform) {
      _Platform.android => _revokeAllAndroid(appId),
      _Platform.iosSimulator => _revokeAllIosSimulator(appId),
      _Platform.none => throw StateError(
          'No supported device tools found. '
          'Ensure adb (Android) or xcrun (iOS Simulator) is available on PATH.',
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // Android (adb)
  // ---------------------------------------------------------------------------

  Future<String> _grantAllAndroid(String appId) async {
    // Get the list of requested permissions from the installed package.
    final requested = await _getRequestedAndroidPermissions(appId);
    if (requested.isEmpty) {
      return 'No runtime permissions found for $appId.';
    }

    final granted = <String>[];
    final skipped = <String>[];

    for (final permission in requested) {
      final result = await Process.run(
        'adb',
        ['shell', 'pm', 'grant', appId, permission],
      );
      if (result.exitCode == 0) {
        granted.add(permission);
        _logger.fine('Granted $permission');
      } else {
        // Permission may not be grantable (e.g. install-time, or already
        // granted). This is expected — just skip it.
        skipped.add(permission);
        _logger.fine('Skipped $permission: ${result.stderr}');
      }
    }

    final buffer = StringBuffer('Android: granted ${granted.length} '
        'permission(s) for $appId.');
    if (granted.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Granted:');
      for (final p in granted) {
        buffer.writeln('  + ${_shortPermission(p)}');
      }
    }
    if (skipped.isNotEmpty) {
      buffer.writeln('Skipped (already granted or not grantable):');
      for (final p in skipped) {
        buffer.writeln('  - ${_shortPermission(p)}');
      }
    }
    return buffer.toString().trimRight();
  }

  Future<String> _revokeAllAndroid(String appId) async {
    final requested = await _getRequestedAndroidPermissions(appId);
    if (requested.isEmpty) {
      return 'No runtime permissions found for $appId.';
    }

    var revoked = 0;
    for (final permission in requested) {
      final result = await Process.run(
        'adb',
        ['shell', 'pm', 'revoke', appId, permission],
      );
      if (result.exitCode == 0) revoked++;
    }

    return 'Android: revoked $revoked permission(s) for $appId.';
  }

  /// Queries `adb shell dumpsys package` for requested runtime permissions.
  Future<List<String>> _getRequestedAndroidPermissions(String appId) async {
    final result = await Process.run(
      'adb',
      ['shell', 'dumpsys', 'package', appId],
    );

    if (result.exitCode != 0) {
      throw StateError(
        'Failed to query package info for $appId: ${result.stderr}',
      );
    }

    final output = result.stdout as String;

    // Parse "requested permissions:" section from dumpsys output.
    final lines = output.split('\n');
    final permissions = <String>[];
    var inSection = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('requested permissions:')) {
        inSection = true;
        continue;
      }
      if (inSection) {
        if (trimmed.startsWith('android.permission.') ||
            trimmed.startsWith('com.google.android') ||
            trimmed.startsWith('com.android')) {
          permissions.add(trimmed);
        } else if (trimmed.isNotEmpty && !trimmed.startsWith('android.')) {
          // End of section — next block started.
          break;
        }
      }
    }

    // Filter to only dangerous (runtime) permissions.
    return permissions.where(_isDangerousPermission).toList();
  }

  /// Known dangerous (runtime) permissions that can be granted via `pm grant`.
  static const _dangerousPermissions = {
    'android.permission.READ_CALENDAR',
    'android.permission.WRITE_CALENDAR',
    'android.permission.CAMERA',
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.GET_ACCOUNTS',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.RECORD_AUDIO',
    'android.permission.READ_PHONE_STATE',
    'android.permission.READ_PHONE_NUMBERS',
    'android.permission.CALL_PHONE',
    'android.permission.ANSWER_PHONE_CALLS',
    'android.permission.ADD_VOICEMAIL',
    'android.permission.USE_SIP',
    'android.permission.BODY_SENSORS',
    'android.permission.BODY_SENSORS_BACKGROUND',
    'android.permission.SEND_SMS',
    'android.permission.RECEIVE_SMS',
    'android.permission.READ_SMS',
    'android.permission.RECEIVE_WAP_PUSH',
    'android.permission.RECEIVE_MMS',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.NEARBY_WIFI_DEVICES',
    'android.permission.BLUETOOTH_SCAN',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.BLUETOOTH_ADVERTISE',
    'android.permission.ACTIVITY_RECOGNITION',
  };

  static bool _isDangerousPermission(String permission) =>
      _dangerousPermissions.contains(permission);

  static String _shortPermission(String permission) =>
      permission.replaceFirst('android.permission.', '');

  // ---------------------------------------------------------------------------
  // iOS Simulator (xcrun simctl)
  // ---------------------------------------------------------------------------

  Future<String> _grantAllIosSimulator(String appId) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'privacy', 'booted', 'grant', 'all', appId],
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw StateError('Failed to grant permissions on iOS Simulator: $stderr');
    }

    return 'iOS Simulator: granted all permissions for $appId.';
  }

  Future<String> _revokeAllIosSimulator(String appId) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'privacy', 'booted', 'reset', 'all', appId],
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw StateError('Failed to reset permissions on iOS Simulator: $stderr');
    }

    return 'iOS Simulator: reset all permissions for $appId.';
  }

  // ---------------------------------------------------------------------------
  // Platform detection
  // ---------------------------------------------------------------------------

  Future<_Platform> _detectPlatform() async {
    // Check for a connected Android device first.
    try {
      final result = await Process.run('adb', ['devices']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n').skip(1); // skip header
        final hasDevice = lines.any(
          (l) => l.trim().isNotEmpty && l.contains('device'),
        );
        if (hasDevice) {
          _logger.fine('Detected Android device via adb');
          return _Platform.android;
        }
      }
    } on ProcessException {
      // adb not found — try iOS.
    }

    // Check for a booted iOS simulator.
    try {
      final result = await Process.run(
        'xcrun',
        ['simctl', 'list', 'devices', 'booted', '-j'],
      );
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        // Simple check: if the JSON output contains a device UUID, there's
        // a booted simulator.
        if (output.contains('"udid"')) {
          _logger.fine('Detected booted iOS Simulator via xcrun simctl');
          return _Platform.iosSimulator;
        }
      }
    } on ProcessException {
      // xcrun not found.
    }

    return _Platform.none;
  }
}

enum _Platform { android, iosSimulator, none }
