import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import '../../core/logging/app_logger.dart';

final class ExampleItem {
  const ExampleItem(this.title);
  final String title;
}

abstract interface class ExampleRepository {
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation);
}

final class ExampleCancellation {
  final _callbacks = <void Function()>[];
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in _callbacks) {
      callback();
    }
    _callbacks.clear();
  }
}

final class FakeExampleRepository implements ExampleRepository {
  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) async {
    if (cancellation.isCancelled) {
      throw const AppException(AppFailure(AppFailureKind.cancelled));
    }
    return const [ExampleItem('Flutter'), ExampleItem('Riverpod')];
  }
}

abstract interface class ExampleService {
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation);
}

/// The service owns protocol parsing and the external failure boundary.
final class ExampleApiService implements ExampleService {
  ExampleApiService(this._dio, {AppLogger? logger})
    : _logger = logger ?? AppLogger();
  final Dio _dio;
  final AppLogger _logger;

  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) async {
    final token = CancelToken();
    // Tie provider disposal to Dio cancellation so navigation away does not
    // leave an unnecessary request running in the background.
    cancellation.onCancel(token.cancel);
    try {
      final response = await _dio.get<Object>('items', cancelToken: token);
      // Validate the wire shape before exposing it to the rest of the app.
      // This keeps malformed or unexpected payloads on the same typed failure
      // path as other API errors instead of leaking casts into UI code.
      final data = response.data;
      if (data is! List) throw const FormatException();
      return data
          .map((item) {
            if (item is! Map || item['title'] is! String) {
              throw const FormatException();
            }
            return ExampleItem(item['title'] as String);
          })
          .toList(growable: false);
    } on AppException {
      rethrow;
    } on DioException catch (error, stack) {
      // Translate Dio's transport-specific taxonomy once, at this boundary.
      // Pages can then render stable AppFailureKind values without knowing
      // which HTTP client or low-level status produced them. Cancellation is
      // also kept distinct because it usually means the page was left, not an
      // error that should be shown to the user.
      final kind = switch (error.type) {
        DioExceptionType.cancel => AppFailureKind.cancelled,
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => AppFailureKind.timeout,
        DioExceptionType.connectionError => AppFailureKind.connection,
        DioExceptionType.badResponse => switch (error.response?.statusCode) {
          401 => AppFailureKind.unauthorized,
          403 => AppFailureKind.forbidden,
          404 => AppFailureKind.notFound,
          429 => AppFailureKind.rateLimited,
          final int status when status >= 500 && status <= 599 =>
            AppFailureKind.server,
          _ => AppFailureKind.unknown,
        },
        DioExceptionType.unknown when error.error is FormatException =>
          AppFailureKind.invalidResponse,
        _ => AppFailureKind.unknown,
      };
      if (kind != AppFailureKind.cancelled) {
        _logger.record(DiagnosticEvent.networkFailure, stack: stack);
      }
      throw AppException(AppFailure(kind), cause: error, stackTrace: stack);
    } on FormatException catch (error, stack) {
      _logger.record(DiagnosticEvent.networkFailure, stack: stack);
      throw AppException(
        const AppFailure(AppFailureKind.invalidResponse),
        cause: error,
        stackTrace: stack,
      );
    } catch (error, stack) {
      _logger.record(DiagnosticEvent.networkFailure, stack: stack);
      throw AppException(
        const AppFailure(AppFailureKind.unknown),
        cause: error,
        stackTrace: stack,
      );
    }
  }
}

/// The repository preserves the service's stable application failures.
final class ApiExampleRepository implements ExampleRepository {
  ApiExampleRepository(Dio dio, {AppLogger? logger})
    : this.withService(ExampleApiService(dio, logger: logger));
  ApiExampleRepository.withService(this._service);
  final ExampleService _service;
  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) =>
      _service.fetch(cancellation);
}
