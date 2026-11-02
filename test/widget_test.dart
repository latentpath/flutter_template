import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/app.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/app/settings/settings.dart';
import 'package:flutter_template/app/startup/startup.dart';

void main() {
  testWidgets(
    'startup failure is rendered without a ProviderScope and can retry',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        StartupCoordinator(
          bootstrap: _Bootstrap(() async {
            calls++;
            if (calls == 1) {
              throw const FormatException('sensitive raw details');
            }
            return _resources();
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The app configuration is invalid.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('settings navigation and selection preserve the current route', (
    tester,
  ) async {
    final repository = MemorySettingsRepository();
    await tester.pumpWidget(
      TemplateApp(resources: _resources(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(repository.value.themeMode, ThemeMode.dark);
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(repository.value.locale, const Locale('zh'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('一个可离线运行的简洁应用起点。'), findsOneWidget);
  });

  testWidgets(
    'system Simplified Chinese locale resolves to Chinese resources',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(TemplateApp(resources: _resources()));
      await tester.pumpAndSettle();
      expect(find.text('一个可离线运行的简洁应用起点。'), findsOneWidget);
    },
  );

  testWidgets(
    'home actions remain reachable in a short viewport with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 220);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(TemplateApp(resources: _resources()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Settings')).bottom,
        lessThanOrEqualTo(220),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
    },
  );

  testWidgets('startup retry waits for asynchronous late-resource cleanup', (
    tester,
  ) async {
    final pending = Completer<BootstrapResources>();
    final cleanupGate = Completer<void>();
    var cleanupStarted = false;
    var cleanupFinished = false;
    var disposed = 0;
    var calls = 0;
    await tester.pumpWidget(
      StartupCoordinator(
        startupBudget: const Duration(milliseconds: 20),
        bootstrap: _Bootstrap(() {
          calls++;
          if (calls == 1) return pending.future;
          return Future.value(_resources());
        }),
      ),
    );
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pumpAndSettle();
    expect(
      find.text('Startup took too long. Wait and retry, or restart the app.'),
      findsOneWidget,
    );
    pending.complete(
      BootstrapResources(
        config: AppConfig.parse(),
        repository: MemorySettingsRepository(),
        initialSettings: const SettingsState(),
        cleanup: [
          () async {
            disposed++;
            cleanupStarted = true;
            await cleanupGate.future;
            cleanupFinished = true;
          },
        ],
      ),
    );
    await tester.pump();
    expect(cleanupStarted, isTrue);
    final retryButton = find.widgetWithText(FilledButton, 'Retry');
    expect(tester.widget<FilledButton>(retryButton).onPressed, isNull);
    cleanupGate.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(disposed, 1);
    expect(cleanupFinished, isTrue);
    expect(tester.widget<FilledButton>(retryButton).onPressed, isNotNull);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('unknown route can return to home', (tester) async {
    await tester.pumpWidget(
      TemplateApp(resources: _resources(), initialLocation: '/missing'),
    );
    await tester.pumpAndSettle();
    expect(find.text('This page could not be found.'), findsOneWidget);
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();
    expect(
      find.text('A simple offline-ready starting point for your app.'),
      findsOneWidget,
    );
  });
}

BootstrapResources _resources({MemorySettingsRepository? repository}) =>
    BootstrapResources(
      config: AppConfig.parse(),
      repository: repository ?? MemorySettingsRepository(),
      initialSettings: const SettingsState(),
    );

final class _Bootstrap implements Bootstrap {
  _Bootstrap(this.action);
  final Future<BootstrapResources> Function() action;
  @override
  Future<BootstrapResources> load() => action();
}
