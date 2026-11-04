import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/core/logging/app_logger.dart';

void main() {
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
