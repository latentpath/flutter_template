import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/config/app_config.dart';
import 'app/settings/settings.dart';
import 'app/startup/startup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('[error-boundary] framework error');
    if (kDebugMode) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: StateError('A framework error occurred'),
          library: 'Flutter framework',
        ),
      );
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // Deliberately omit raw exceptions and stack traces from the default logger.
    debugPrint('[error-boundary] uncaught main-isolate error');
    return true;
  };
  runApp(
    StartupCoordinator(
      bootstrap: DefaultBootstrap(
        configLoader: AppConfig.fromEnvironment,
        repositoryFactory: PreferencesSettingsRepository.new,
      ),
    ),
  );
}
