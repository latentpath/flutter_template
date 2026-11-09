import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import 'app_logger.dart';

/// Installs boundaries that never forward raw framework or isolate diagnostics.
void installErrorHandlers(AppLogger logger) {
  FlutterError.onError = (details) {
    logger.record(DiagnosticEvent.frameworkError, stack: details.stack);
    if (kDebugMode) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: StateError('A framework error occurred'),
          library: 'Flutter framework',
        ),
      );
    }
  };
  ErrorWidget.builder = (_) => Builder(
    builder: (context) => Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Text(
        Localizations.of<AppLocalizations>(
              context,
              AppLocalizations,
            )?.unexpectedError ??
            'This part of the app could not be displayed.',
      ),
    ),
  );
  PlatformDispatcher.instance.onError = (_, stack) {
    logger.record(DiagnosticEvent.isolateError, stack: stack);
    return true;
  };
}
