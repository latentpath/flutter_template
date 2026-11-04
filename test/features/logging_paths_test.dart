import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/startup/startup.dart';
import 'package:flutter_template/core/logging/app_logger.dart';
import 'package:flutter_template/features/example/example_repository.dart';

final class FailingBootstrap implements Bootstrap {
  @override
  Future<BootstrapResources> load() async => throw StateError('secret-token');
}

void main() {
  testWidgets('startup failure logs only a safe category', (tester) async {
    final messages = <String>[];
    await tester.pumpWidget(
      StartupCoordinator(
        bootstrap: FailingBootstrap(),
        logger: AppLogger(sink: messages.add),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The app could not start.'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(messages.join(), contains('startupFailure'));
    expect(messages.join(), isNot(contains('secret-token')));
  });
  test('network failure logs no request or response diagnostics', () async {
    final messages = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            message: 'secret-token',
            error: StateError('secret-token'),
          ),
        ),
      ),
    );
    final repo = ApiExampleRepository(
      dio,
      logger: AppLogger(sink: messages.add),
    );
    await expectLater(repo.fetch(ExampleCancellation()), throwsA(anything));
    expect(messages, ['[app] networkFailure']);
  });
}
