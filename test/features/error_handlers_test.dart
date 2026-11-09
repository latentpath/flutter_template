import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/core/logging/app_logger.dart';
import 'package:flutter_template/core/logging/error_handlers.dart';

void main() {
  testWidgets('framework, isolate and error widget omit raw diagnostics', (
    tester,
  ) async {
    final originalError = FlutterError.onError;
    final originalBuilder = ErrorWidget.builder;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final originalIsolate = dispatcher.onError;
    final originalPrint = debugPrint;
    final messages = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      messages.add(message ?? '');
    };
    installErrorHandlers(AppLogger(sink: messages.add));
    final details = FlutterErrorDetails(
      exception: StateError('secret-token'),
      stack: StackTrace.fromString('secret-token'),
      context: ErrorDescription('secret-token'),
      informationCollector: () => [ErrorDescription('secret-token')],
    );
    FlutterError.onError!(details);
    final handled = dispatcher.onError!(
      StateError('secret-token'),
      StackTrace.fromString('secret-token'),
    );
    final widget = ErrorWidget.builder(details);
    FlutterError.onError = originalError;
    ErrorWidget.builder = originalBuilder;
    dispatcher.onError = originalIsolate;
    debugPrint = originalPrint;
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: widget),
    );
    expect(handled, isTrue);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(
      find.text('This part of the app could not be displayed.'),
      findsOneWidget,
    );
    expect(messages.join(), contains('stack=[redacted]'));
    expect(messages.join('\n'), isNot(contains('secret-token')));
    expect(messages.join('\n'), contains('frameworkError'));
    expect(messages.join('\n'), contains('isolateError'));
  });
}
