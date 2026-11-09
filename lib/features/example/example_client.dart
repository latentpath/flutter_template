import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import 'example_repository.dart';
import '../../core/logging/app_logger.dart';

/// Lazily owns the repository and, in API mode, its single Dio client.
/// Fake mode never creates a network client, while resource disposal closes
/// the client at the application boundary rather than from a page or provider.
final class ExampleClientOwner {
  ExampleClientOwner(
    this.config, {
    this.createDio = Dio.new,
    AppLogger? logger,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
  }) : logger = logger ?? AppLogger();
  final AppConfig config;
  final AppLogger logger;
  final Dio Function(BaseOptions) createDio;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  Dio? _client;
  ExampleRepository? _repository;
  bool _disposed = false;

  ExampleRepository get repository {
    if (_disposed) throw StateError('Client owner disposed');
    return _repository ??= _createRepository();
  }

  ExampleRepository _createRepository() {
    if (config.dataSourceMode == DataSourceMode.fake) {
      return FakeExampleRepository();
    }
    final base = config.apiBaseUri!;
    final normalized = base.replace(
      path: base.path.endsWith('/') ? base.path : '${base.path}/',
    );
    final client = createDio(
      BaseOptions(
        baseUrl: normalized.toString(),
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        followRedirects: false,
      ),
    );
    _client = client;
    return ApiExampleRepository(client, logger: logger);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client?.close(force: true);
  }
}
