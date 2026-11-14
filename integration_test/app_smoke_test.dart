import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_template/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final preferences = SharedPreferencesAsync();
  String? previousTheme;
  String? previousLocale;

  setUp(() async {
    previousTheme = await preferences.getString('settings.theme_mode');
    previousLocale = await preferences.getString('settings.locale');
    await preferences.setString('settings.theme_mode', 'light');
    await preferences.setString('settings.locale', 'en');
  });

  tearDown(() async {
    if (previousTheme == null) {
      await preferences.remove('settings.theme_mode');
    } else {
      await preferences.setString('settings.theme_mode', previousTheme!);
    }
    if (previousLocale == null) {
      await preferences.remove('settings.locale');
    } else {
      await preferences.setString('settings.locale', previousLocale!);
    }
  });

  testWidgets('starts app and navigates through settings and example', (
    tester,
  ) async {
    final frameworkErrorHandler = FlutterError.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final platformErrorHandler = dispatcher.onError;
    try {
      app.main();
    } finally {
      // main installs application error handlers. Restore the test handlers
      // before pumping so framework errors and failed assertions reach the
      // binding, even when starting the application throws.
      FlutterError.onError = frameworkErrorHandler;
      ErrorWidget.builder = errorWidgetBuilder;
      dispatcher.onError = platformErrorHandler;
    }
    await tester.pumpAndSettle();
    expect(
      find.text('A simple offline-ready starting point for your app.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Data example'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
