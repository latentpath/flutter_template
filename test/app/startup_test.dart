import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/app/settings/settings.dart';
import 'package:flutter_template/app/startup/startup.dart';

void main() {
  test(
    'preference read failure uses defaults and does not write defaults back',
    () async {
      final repository = _FailingReadRepository();
      final resources = await DefaultBootstrap(
        configLoader: AppConfig.fromEnvironment,
        repositoryFactory: () => repository,
      ).load();

      expect(resources.initialSettings, const SettingsState());
      expect(repository.writes, 0);
    },
  );

  test(
    'preference read timeout uses defaults and does not write them back',
    () async {
      final repository = _DelayedReadRepository();
      final resources = await DefaultBootstrap(
        configLoader: AppConfig.fromEnvironment,
        repositoryFactory: () => repository,
        preferenceBudget: const Duration(milliseconds: 1),
      ).load();

      expect(resources.initialSettings, const SettingsState());
      expect(repository.writes, 0);
      repository.readResult.complete(
        const SettingsState(themeMode: ThemeMode.dark),
      );
      await Future<void>.delayed(Duration.zero);
      expect(resources.initialSettings, const SettingsState());
      expect(repository.writes, 0);
    },
  );

  test('resource cleanup is reverse ordered and idempotent', () async {
    final released = <int>[];
    final resources = BootstrapResources(
      config: AppConfig.parse(),
      repository: MemorySettingsRepository(),
      initialSettings: const SettingsState(),
      cleanup: [() => released.add(1), () => released.add(2)],
    );

    await resources.dispose();
    await resources.dispose();

    expect(released, [2, 1]);
  });
}

final class _FailingReadRepository implements SettingsRepository {
  int writes = 0;
  @override
  Future<SettingsState> read() =>
      Future.error(const SettingsStorageException());
  @override
  Future<void> writeThemeMode(ThemeMode value) async => writes++;
  @override
  Future<void> writeLocale(Locale? value) async => writes++;
}

final class _DelayedReadRepository implements SettingsRepository {
  final readResult = Completer<SettingsState>();
  int writes = 0;

  @override
  Future<SettingsState> read() => readResult.future;

  @override
  Future<void> writeThemeMode(ThemeMode value) async => writes++;

  @override
  Future<void> writeLocale(Locale? value) async => writes++;
}
