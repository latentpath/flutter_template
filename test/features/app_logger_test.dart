import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/core/logging/app_logger.dart';

void main() {
  test('levels respect debug mode and environment is allowlisted', () {
    final messages = <String>[];
    final production = AppLogger(sink: messages.add, environment: 'production');
    production.record(DiagnosticEvent.errorView, level: DiagnosticLevel.info);
    expect(messages, isEmpty);
    final logger = AppLogger(
      sink: messages.add,
      debugEnabled: false,
      environment: 'secret-token',
    );
    logger.record(DiagnosticEvent.errorView, level: DiagnosticLevel.debug);
    expect(messages, isEmpty);
    logger.record(
      DiagnosticEvent.errorView,
      level: DiagnosticLevel.info,
      stack: StackTrace.fromString('secret-token'),
    );
    expect(messages.single, contains('level=info environment=unknown'));
    expect(messages.single, contains('stack=[redacted]'));
    expect(messages.single, isNot(contains('secret-token')));
    messages.clear();
    logger.record(
      DiagnosticEvent.frameworkError,
      stack: StackTrace.fromString(
        '#1 secret-token (package:secret-token/file.dart:12:3)',
      ),
    );
    expect(messages.single, contains('stack=[#1:line12]'));
    expect(messages.single, isNot(contains('secret-token')));
  });

  test('logger emits fixed categories only and tolerates sink failure', () {
    final messages = <String>[];
    final logger = AppLogger(sink: messages.add);
    for (final event in DiagnosticEvent.values) {
      logger.record(event);
    }
    expect(messages, everyElement(startsWith('[app] ')));
    expect(messages.join(), isNot(contains('simulated-secret-token')));
    expect(
      () =>
          AppLogger(sink: (_) => throw StateError('simulated-secret-token'))
              .record(DiagnosticEvent.frameworkError),
      returnsNormally,
    );
  });
}
