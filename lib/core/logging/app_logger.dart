import 'package:flutter/foundation.dart';

enum DiagnosticEvent {
  frameworkError,
  isolateError,
  startupFailure,
  networkFailure,
  errorView,
}

/// Only fixed event names can reach the sink; no exception text is accepted.
final class AppLogger {
  AppLogger({void Function(String)? sink}) : _sink = sink ?? debugPrint;
  final void Function(String) _sink;
  void record(DiagnosticEvent event) {
    try {
      _sink('[app] ${event.name}');
    } catch (_) {
      try {
        debugPrint('[app] loggingFailure');
      } catch (_) {
        /* Output may be unavailable. */
      }
    }
  }
}
