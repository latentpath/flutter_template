import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/app/settings/settings.dart';
import 'package:flutter_template/app/startup/bootstrap_resources.dart';
// The plugin's locked platform interface supplies its official in-memory test implementation.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'preferences normalize each key and write only the selected key',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            PreferencesSettingsRepository.themeKey: 7,
            PreferencesSettingsRepository.localeKey: 'zh',
          });
      final repository = PreferencesSettingsRepository();
      expect(
        await repository.read(),
        const SettingsState(locale: Locale('zh')),
      );
      await repository.writeThemeMode(ThemeMode.dark);
      expect(
        await repository.read(),
        const SettingsState(themeMode: ThemeMode.dark, locale: Locale('zh')),
      );
      await repository.writeLocale(null);
      expect(
        await repository.read(),
        const SettingsState(themeMode: ThemeMode.dark),
      );
    },
  );

  test(
    'abandoned generation cancels queued work and recovery waits then rereads',
    () async {
      final repository = _DelayedRepository();
      final resources = BootstrapResources(
        config: AppConfig.parse(),
        repository: repository,
        initialSettings: const SettingsState(),
      );
      final queue = resources.settingsQueue;
      final first = queue.enqueue(queue.generation, () async {
        await repository.writeThemeMode(ThemeMode.dark);
        return const SettingsWriteSuccess(
          SettingsState(themeMode: ThemeMode.dark),
        );
      });
      var ran = false;
      final second = queue.enqueue(queue.generation, () async {
        ran = true;
        return const SettingsWriteSuccess(SettingsState());
      });
      await Future<void>.delayed(Duration.zero);
      queue.abandon(queue.generation);
      final recovery = resources.recoverSettings();
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, 0);
      expect(queue.isOpen, isFalse);
      repository.write.complete();
      expect(await first, isA<SettingsWriteSuccess>());
      expect(
        (await second as SettingsWriteFailure).kind,
        SettingsFailureKind.cancelled,
      );
      await recovery;
      expect(ran, isFalse);
      expect(resources.initialSettings.themeMode, ThemeMode.dark);
      expect(queue.isOpen, isTrue);
      await resources.dispose();
    },
  );

  test('recovery timeout does not bypass the in-flight write', () async {
    final repository = _DelayedRepository();
    final resources = BootstrapResources(
      config: AppConfig.parse(),
      repository: repository,
      initialSettings: const SettingsState(),
    );
    final queue = resources.settingsQueue;
    final write = queue.enqueue(queue.generation, () async {
      await repository.writeThemeMode(ThemeMode.dark);
      return const SettingsWriteSuccess(SettingsState());
    });
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      resources.recoverSettings(budget: const Duration(milliseconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    expect(queue.isOpen, isFalse);
    expect(repository.reads, 0);
    repository.write.complete();
    await write;
    await resources.dispose();
  });

  test('disposed notifier cannot publish, queued command cancels, and new state rereads', () async {
    final repository = _DelayedRepository();
    final resources = BootstrapResources(
      config: AppConfig.parse(),
      repository: repository,
      initialSettings: const SettingsState(),
    );
    final container = ProviderContainer(
      overrides: [
        settingsQueueProvider.overrideWithValue(resources.settingsQueue),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final notifier = container.read(settingsProvider.notifier);
    final first = notifier.setThemeMode(ThemeMode.dark);
    final second = notifier.setLocale(const Locale('en'));
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    final recovery = resources.recoverSettings();
    repository.write.complete();
    expect(await first, isA<SettingsWriteSuccess>());
    expect(
      (await second as SettingsWriteFailure).kind,
      SettingsFailureKind.cancelled,
    );
    await recovery;
    final newContainer = ProviderContainer(
      overrides: [
        settingsQueueProvider.overrideWithValue(resources.settingsQueue),
        settingsRepositoryProvider.overrideWithValue(repository),
        settingsInitialStateProvider.overrideWithValue(
          resources.initialSettings,
        ),
      ],
    );
    expect(newContainer.read(settingsProvider).themeMode, ThemeMode.dark);
    resources.settingsQueue.closeForDrain();
    newContainer.dispose();
    await resources.dispose();
  });

  test('unexpected task error does not poison FIFO', () async {
    final queue = SettingsCommandQueue();
    final failed = queue.enqueue(
      queue.generation,
      () async => throw StateError('bug'),
    );
    final next = queue.enqueue(
      queue.generation,
      () async => const SettingsWriteSuccess(SettingsState()),
    );
    await expectLater(failed, throwsStateError);
    expect(await next, isA<SettingsWriteSuccess>());
  });
}

final class _DelayedRepository implements SettingsRepository {
  final write = Completer<void>();
  int reads = 0;
  SettingsState value = const SettingsState();
  @override
  Future<SettingsState> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    await write.future;
    value = value.copyWith(themeMode: mode);
  }

  @override
  Future<void> writeLocale(Locale? locale) async {}
}
