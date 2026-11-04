import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_logger.dart';

/// Installs boundaries that never forward raw framework or isolate diagnostics.
void installErrorHandlers(AppLogger logger) {
  FlutterError.onError = (_) {
    logger.record(DiagnosticEvent.frameworkError);
    if (kDebugMode) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: StateError('A framework error occurred'),
          library: 'Flutter framework',
        ),
      );
    }
  };
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  PlatformDispatcher.instance.onError = (_, _) {
    logger.record(DiagnosticEvent.isolateError);
    return true;
  };
}
