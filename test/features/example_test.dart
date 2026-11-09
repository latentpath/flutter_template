import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/features/example/example_client.dart';
import 'package:flutter_template/features/example/example_repository.dart';

void main() {
  test('fake mode never creates a client in any environment', () async {
    for (final environment in ['development', 'staging', 'production']) {
      var clients = 0;
      final owner = ExampleClientOwner(
        AppConfig.parse(appEnv: environment),
        createDio: (options) {
          clients++;
          return Dio(options);
        },
      );
      expect(await owner.repository.fetch(ExampleCancellation()), hasLength(2));
      owner.dispose();
      expect(clients, 0);
    }
  });

  test(
    'API uses normalized base path, configured timeouts and closes',
    () async {
      late Dio client;
      final owner = ExampleClientOwner(
        AppConfig.parse(
          dataSourceMode: 'api',
          apiBaseUri: 'https://flutter.dev/v1',
        ),
        createDio: (options) {
          client = Dio(options);
          client.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                expect(options.uri.toString(), 'https://flutter.dev/v1/items');
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: [
                      {'title': 'sample'},
                    ],
                    statusCode: 200,
                  ),
                );
              },
            ),
          );
          return client;
        },
      );
      expect(
        (await owner.repository.fetch(ExampleCancellation())).single.title,
        'sample',
      );
      expect(client.options.connectTimeout, const Duration(seconds: 10));
      expect(client.options.receiveTimeout, const Duration(seconds: 30));
      expect(client.options.sendTimeout, const Duration(seconds: 30));
      owner.dispose();
      expect(() => owner.repository, throwsStateError);
    },
  );

  for (final entry in <(int, AppFailureKind)>[
    (401, AppFailureKind.unauthorized),
    (403, AppFailureKind.forbidden),
    (404, AppFailureKind.notFound),
    (429, AppFailureKind.rateLimited),
    (503, AppFailureKind.server),
  ]) {
    test('maps HTTP ${entry.$1}', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: options, statusCode: entry.$1),
            ),
          ),
        ),
      );
      await expectLater(
        ApiExampleRepository(dio).fetch(ExampleCancellation()),
        throwsA(
          isA<AppException>().having((e) => e.failure.kind, 'kind', entry.$2),
        ),
      );
    });
  }

  for (final entry in <(DioExceptionType, AppFailureKind)>[
    (DioExceptionType.cancel, AppFailureKind.cancelled),
    (DioExceptionType.connectionTimeout, AppFailureKind.timeout),
    (DioExceptionType.receiveTimeout, AppFailureKind.timeout),
    (DioExceptionType.sendTimeout, AppFailureKind.timeout),
    (DioExceptionType.connectionError, AppFailureKind.connection),
    (DioExceptionType.unknown, AppFailureKind.unknown),
  ]) {
    test('maps ${entry.$1}', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(requestOptions: options, type: entry.$1),
          ),
        ),
      );
      await expectLater(
        ApiExampleRepository(dio).fetch(ExampleCancellation()),
        throwsA(
          isA<AppException>().having((e) => e.failure.kind, 'kind', entry.$2),
        ),
      );
    });
  }
  test('invalid payload has safe failure', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(requestOptions: options, data: {'token': 'secret'}),
        ),
      ),
    );
    await expectLater(
      ApiExampleRepository(dio).fetch(ExampleCancellation()),
      throwsA(
        isA<AppException>().having(
          (e) => e.failure.kind,
          'kind',
          AppFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
