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

  bool _disposed = false;
  Future<void>? _disposeFuture;
  final Set<Future<void>> _pendingReads = {};

  Future<void> recoverSettings({
    Duration budget = const Duration(seconds: 5),
  }) async {
    if (_disposed) throw StateError('Resources are disposed');
    settingsQueue.closeForDrain();
    // Stop accepting new commands, then let already accepted writes finish
    // before reading storage. Otherwise a write could complete after the read
    // and make the recovered UI state disagree with persisted settings. The
    // queue is reopened only after the new snapshot is ready for a fresh scope.
    final timer = Stopwatch()..start();
    await settingsQueue.drained.timeout(budget);
    if (_disposed) throw StateError('Resources are disposed');
    final remaining = budget - timer.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Settings recovery timed out');
    }
    final read = repository.read();
    final barrier = read.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pendingReads.add(barrier);
    unawaited(barrier.then((_) => _pendingReads.remove(barrier)));
    final recovered = await read.timeout(remaining);
    if (_disposed) throw StateError('Resources are disposed');
    initialSettings = recovered;
    settingsQueue.reopen();
  }

  final List<FutureOr<void> Function()> cleanup;
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    settingsQueue.closeForDrain();
    exampleClient.dispose();
    await settingsQueue.drained;
    // A timed-out read is still running and may still be using the repository.
    // Keep its completion barrier until it settles, then release injected
    // dependencies so shutdown does not race outstanding repository work.
    await Future.wait(_pendingReads.toList());
    for (final release in cleanup.reversed) {
      try {
        await release();
      } catch (_) {
        // Cleanup errors stay inside the resource boundary.
      }
    }
  }
}
