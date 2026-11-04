import 'dart:async';

import '../../features/example/example_client.dart';
import '../../core/logging/app_logger.dart';
import '../config/app_config.dart';
import '../settings/settings.dart';

final class BootstrapResources {
  BootstrapResources({
    required this.config,
    required this.repository,
    required this.initialSettings,
    this.cleanup = const [],
    AppLogger? logger,
  }) : logger = logger ?? AppLogger();

  final AppLogger logger;
  final AppConfig config;
  late final ExampleClientOwner exampleClient = ExampleClientOwner(
    config,
    logger: logger,
  );
  final SettingsRepository repository;
  SettingsState initialSettings;
  final SettingsCommandQueue settingsQueue = SettingsCommandQueue();

  Future<void> recoverSettings({
    Duration budget = const Duration(seconds: 5),
  }) async {
    settingsQueue.closeForDrain();
    final timer = Stopwatch()..start();
    await settingsQueue.drained.timeout(budget);
    final remaining = budget - timer.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Settings recovery timed out');
    }
    initialSettings = await repository.read().timeout(remaining);
    settingsQueue.reopen();
  }

  final List<FutureOr<void> Function()> cleanup;
  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    settingsQueue.closeForDrain();
    exampleClient.dispose();
    await settingsQueue.drained;
    for (final release in cleanup.reversed) {
      try {
        await release();
      } catch (_) {
        // Cleanup errors stay inside the resource boundary.
      }
    }
  }
}
