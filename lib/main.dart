import 'package:flutter/widgets.dart';

import 'app/config/app_config.dart';
import 'app/settings/settings.dart';
import 'app/startup/startup.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/error_handlers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();
  installErrorHandlers(logger);
  runApp(
    StartupCoordinator(
      logger: logger,
      bootstrap: DefaultBootstrap(
        logger: logger,
        configLoader: AppConfig.fromEnvironment,
        repositoryFactory: PreferencesSettingsRepository.new,
      ),
    ),
  );
}
