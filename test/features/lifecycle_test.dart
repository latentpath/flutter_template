import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/features/example/example_client.dart';
import 'package:flutter_template/features/example/example_repository.dart';

final class ControlledAdapter implements HttpClientAdapter {
  bool closed = false;
  bool? forced;
  final started = Completer<void>();
  final cancelled = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await cancelFuture;
    cancelled.complete();
    throw DioException(requestOptions: options, type: DioExceptionType.cancel);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    forced = force;
  }
}

final class FailingService implements ExampleService {
  FailingService(this.failure);
  final AppException failure;
  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) async =>
      throw failure;
}

void main() {
  test(
    'cancellation reaches in-flight adapter and owner closes client',
    () async {
      final adapter = ControlledAdapter();
      final owner = ExampleClientOwner(
        AppConfig.parse(
          dataSourceMode: 'api',
          apiBaseUri: 'https://flutter.dev/api',
        ),
        createDio: (options) => Dio(options)..httpClientAdapter = adapter,
      );
      final cancel = ExampleCancellation();
      final result = owner.repository.fetch(cancel);
      final expectation = expectLater(
        result,
        throwsA(
          isA<AppException>().having(
            (e) => e.failure.kind,
            'kind',
            AppFailureKind.cancelled,
          ),
        ),
      );
      await adapter.started.future;
      cancel.cancel();
      await expectation;
      await adapter.cancelled.future;
      owner.dispose();
      expect(adapter.closed, isTrue);
      expect(adapter.forced, isTrue);
    },
  );
  test('repository preserves already classified failures', () async {
    final failure = AppException(const AppFailure(AppFailureKind.forbidden));
    final repo = ApiExampleRepository.withService(FailingService(failure));
    await expectLater(
      repo.fetch(ExampleCancellation()),
      throwsA(same(failure)),
    );
  });
}
