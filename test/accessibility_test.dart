import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/app.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/app/settings/settings.dart';
import 'package:flutter_template/app/startup/bootstrap_resources.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/features/example/example_page.dart';
import 'package:flutter_template/features/example/example_repository.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets('settings remain accessible at 320px and 2x text ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final resources = BootstrapResources(
        config: AppConfig.parse(),
        repository: MemorySettingsRepository(),
        initialSettings: SettingsState(locale: locale),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final disposal = resources.dispose();
        // Resource cleanup awaits futures created in the test's fake clock.
        await tester.pump();
        await disposal;
      });
      await tester.pumpWidget(TemplateApp(resources: resources));
      await tester.pumpAndSettle();

      final settingsLabel = locale.languageCode == 'zh' ? '设置' : 'Settings';
      await tester.ensureVisible(find.text(settingsLabel));
      final settingsSemantics = tester.getSemantics(
        find.bySemanticsLabel(settingsLabel),
      );
      expect(
        settingsSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(find.text(settingsLabel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      final themeLabel = locale.languageCode == 'zh' ? '外观' : 'Appearance';
      expect(find.text(themeLabel), findsOneWidget);
      final selectedTheme = tester.getSemantics(
        find.descendant(
          of: find.byType(RadioGroup<ThemeMode>),
          matching: find.bySemanticsLabel(
            locale.languageCode == 'zh' ? '跟随系统' : 'Follow system',
          ),
        ),
      );
      expect(
        selectedTheme.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      await tester.ensureVisible(find.byType(RadioListTile<ThemeMode>).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final back = find.byType(BackButton);
      expect(back, findsOneWidget);
      expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(
        find.text(locale.languageCode == 'zh' ? '首页' : 'Home'),
        findsOneWidget,
      );
    });

    for (final state in ['loading', 'error', 'empty', 'success']) {
      testWidgets('example $state fits at 320px and 2x text ($locale)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final repository = _AccessibilityExampleRepository();
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              exampleRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ExamplePage(),
            ),
          ),
        );

        if (state != 'loading') {
          switch (state) {
            case 'error':
              repository.result.completeError(
                const AppException(AppFailure(AppFailureKind.connection)),
              );
            case 'empty':
              repository.result.complete(const []);
            case 'success':
              repository.result.complete(const [
                ExampleItem('A long example item that remains readable'),
              ]);
          }
          await tester.pumpAndSettle();
        }

        if (state == 'loading') {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        } else if (state == 'error') {
          expect(
            find.text(
              locale.languageCode == 'zh'
                  ? '无法连接，请检查网络。'
                  : 'Could not connect. Check your connection.',
            ),
            findsOneWidget,
          );
          expect(
            find.text(locale.languageCode == 'zh' ? '重试' : 'Retry'),
            findsOneWidget,
          );
        } else if (state == 'empty') {
          expect(
            find.text(
              locale.languageCode == 'zh' ? '暂无数据。' : 'No data available.',
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.text('A long example item that remains readable'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

final class _AccessibilityExampleRepository implements ExampleRepository {
  final result = Completer<List<ExampleItem>>();

  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) =>
      result.future;
}
