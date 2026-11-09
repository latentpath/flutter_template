import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/startup/startup.dart';
import 'package:flutter_template/core/logging/app_logger.dart';
import 'package:flutter_template/features/example/example_repository.dart';

final class FailingBootstrap implements Bootstrap {
  @override
  Future<BootstrapResources> load() async => throw StateError('secret-token');
}

final class PendingBootstrap implements Bootstrap {
  final completer = Completer<BootstrapResources>();
  @override
  Future<BootstrapResources> load() => completer.future;
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
    expect(
      messages.where((message) => message.contains('startupFailure')),
      hasLength(1),
    );
    expect(messages.join(), isNot(contains('secret-token')));
  });
  testWidgets('late bootstrap failure is recorded once after timeout', (
    tester,
  ) async {
    final messages = <String>[];
    final bootstrap = PendingBootstrap();
    await tester.pumpWidget(
      StartupCoordinator(
        bootstrap: bootstrap,
        startupBudget: const Duration(milliseconds: 100),
        logger: AppLogger(sink: messages.add),
      ),
    );
    await tester.pump(const Duration(milliseconds: 101));
    expect(
      messages.where((message) => message.contains('startupFailure')),
      hasLength(1),
    );
    bootstrap.completer.completeError(StateError('secret-token'));
    await tester.pump();
    expect(
      messages.where((message) => message.contains('startupFailure')),
      hasLength(2),
    );
    expect(messages.join(), isNot(contains('secret-token')));
    await tester.pumpWidget(const SizedBox());
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
    expect(messages.single, contains('[app] networkFailure level=warning'));
    expect(messages.single, isNot(contains('secret-token')));
  });
}
