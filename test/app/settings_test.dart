import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/settings/settings.dart';

void main() {
  test(
    'serializes cross-key writes and continues after a failed write',
    () async {
      final repository = _ControlledRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          settingsInitialStateProvider.overrideWithValue(const SettingsState()),
        ],
        retry: (count, error) => null,
      );
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);
      final first = notifier.setThemeMode(ThemeMode.dark);
      final second = notifier.setLocale(const Locale('zh'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.themeWrites, 1);
      expect(repository.localeWrites, 0);
      repository.theme.complete();
      expect(await first, isA<SettingsWriteSuccess>());
      expect(repository.localeWrites, 1);
      repository.locale.completeError(const SettingsStorageException());
      expect(await second, isA<SettingsWriteFailure>());
      expect(
        container.read(settingsProvider),
        const SettingsState(themeMode: ThemeMode.dark),
      );
      final third = await notifier.setLocale(const Locale('en'));
      expect(third, isA<SettingsWriteSuccess>());
      expect(container.read(settingsProvider).locale, const Locale('en'));
    },
  );

  test('rejects unsupported locales without writing', () async {
    final repository = MemorySettingsRepository();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    expect(
      await container
          .read(settingsProvider.notifier)
          .setLocale(const Locale('fr')),
      isA<SettingsWriteFailure>(),
    );
    expect(repository.value.locale, isNull);
  });
}

final class _ControlledRepository implements SettingsRepository {
  final theme = Completer<void>();
  final locale = Completer<void>();
  int themeWrites = 0;
  int localeWrites = 0;
  @override
  Future<SettingsState> read() async => const SettingsState();
  @override
  Future<void> writeThemeMode(ThemeMode value) {
    themeWrites++;
    return theme.future;
  }

  @override
  Future<void> writeLocale(Locale? value) {
    localeWrites++;
    if (localeWrites > 1) return Future<void>.value();
    return locale.future;
  }
}
