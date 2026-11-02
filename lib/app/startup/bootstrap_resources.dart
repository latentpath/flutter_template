import 'dart:async';

import '../config/app_config.dart';
import '../settings/settings.dart';

final class BootstrapResources {
  BootstrapResources({
    required this.config,
    required this.repository,
    required this.initialSettings,
    this.cleanup = const [],
  });

  final AppConfig config;
  final SettingsRepository repository;
  final SettingsState initialSettings;
  final List<FutureOr<void> Function()> cleanup;
  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final release in cleanup.reversed) {
      try {
        await release();
      } catch (_) {
        // Cleanup errors stay inside the resource boundary.
      }
    }
  }
}
