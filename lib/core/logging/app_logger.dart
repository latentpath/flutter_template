import 'dart:math';

import 'package:flutter/foundation.dart';

enum DiagnosticLevel { debug, info, warning, error }

enum DiagnosticEvent {
  frameworkError,
  isolateError,
  startupFailure,
  networkFailure,
  errorView,
}

/// The sink receives only fixed categories and generated diagnostic metadata.
final class AppLogger {
  AppLogger({
    void Function(String)? sink,
    String environment = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    this.debugEnabled = kDebugMode,
  }) : _sink = sink ?? debugPrint,
       _environment = switch (environment) {
         'development' || 'staging' || 'production' => environment,
         _ => 'unknown',
       };

  final void Function(String) _sink;
  final String _environment;
  final bool debugEnabled;
  static int _sequence = 0;

  void record(
    DiagnosticEvent event, {
    DiagnosticLevel? level,
    StackTrace? stack,
  }) {
    final actualLevel =
        level ??
        switch (event) {
          DiagnosticEvent.startupFailure ||
          DiagnosticEvent.networkFailure => DiagnosticLevel.warning,
          _ => DiagnosticLevel.error,
        };
    if (actualLevel == DiagnosticLevel.debug && !debugEnabled) return;
    if (actualLevel == DiagnosticLevel.info && _environment == 'production') {
      return;
    }
    try {
      // Diagnostic events and levels are fixed enums, and the stack is reduced
      // to safe frame metadata below. Avoid interpolating exceptions or raw
      // traces here: their messages and paths may contain request or user data.
      final stackInfo = stack == null ? '' : ' stack=${_safeStack(stack)}';
      final id =
          '${Random.secure().nextInt(0x7fffffff).toRadixString(16)}-${_sequence++}';
      _sink(
        '[app] ${event.name} level=${actualLevel.name} '
        'environment=$_environment id=$id$stackInfo',
      );
    } catch (_) {
      try {
        debugPrint('[app] loggingFailure');
      } catch (_) {
        // Output may be unavailable.
      }
    }
  }
}

// Never emit method names, filenames, exception messages or arbitrary input.
String _safeStack(StackTrace stack) {
  try {
    final frames = <String>[];
    final framePattern = RegExp(
      r'^#(\d{1,4})\s+.*\((?:package|dart):[^\s]+:(\d{1,6}):\d{1,4}\)$',
    );
    for (final line in stack.toString().split('\n')) {
      // Accept only the known Dart/Flutter frame shape, then keep its frame
      // index and line number. Paths, method names and any unmatched text are
      // discarded; cap the list to bound log size even for deep traces.
      final match = framePattern.firstMatch(line);
      if (match != null) {
        frames.add('#${match[1]}:line${match[2]}');
        if (frames.length == 8) break;
      }
    }
    return frames.isEmpty ? '[redacted]' : '[${frames.join(',')}]';
  } catch (_) {
    return '[redacted]';
  }
}
