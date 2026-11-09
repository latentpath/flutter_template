import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/app.dart';
import 'package:flutter_template/app/config/app_config.dart';
import 'package:flutter_template/app/settings/settings.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/app/startup/bootstrap_resources.dart';
// The plugin's locked platform interface supplies its official in-memory test implementation.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

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
    'preference errors are classified once without retrying writes',
    () async {
      final platform = _FailingPreferences();
      SharedPreferencesAsyncPlatform.instance = platform;
      final repository = PreferencesSettingsRepository();
      await expectLater(
        repository.read(),
        throwsA(
          isA<AppException>()
              .having((e) => e.failure.kind, 'kind', AppFailureKind.storageRead)
              .having((e) => e.cause, 'cause', isA<Exception>())
              .having((e) => e.stackTrace, 'stack', isNotNull),
        ),
      );
      await expectLater(
        repository.writeThemeMode(ThemeMode.dark),
        throwsA(
          isA<AppException>().having(
            (e) => e.failure.kind,
            'kind',
            AppFailureKind.storageWrite,
          ),
        ),
      );
      expect(platform.writes, 1);
    },
  );

  test(
    'recovery keeps commands closed until the delayed read completes',
    () async {
      final repository = _DelayedReadRepository();
      final resources = BootstrapResources(
        config: AppConfig.parse(),
        repository: repository,
        initialSettings: const SettingsState(),
      );
      final queue = resources.settingsQueue;
      final recovery = resources.recoverSettings();
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, 1);
      var called = false;
      final rejected = await queue.enqueue(queue.generation, () async {
        called = true;
        return const SettingsWriteSuccess(SettingsState());
      });
      expect(
        (rejected as SettingsWriteFailure).failure.kind,
        AppFailureKind.cancelled,
      );
      expect(called, isFalse);
      expect(queue.isOpen, isFalse);
      repository.readResult.complete(
        const SettingsState(themeMode: ThemeMode.dark),
      );
      await recovery;
      expect(queue.isOpen, isTrue);
      expect(resources.initialSettings.themeMode, ThemeMode.dark);
      expect(
        await queue.enqueue(
          queue.generation,
          () async => const SettingsWriteSuccess(SettingsState()),
        ),
        isA<SettingsWriteSuccess>(),
      );
      await resources.dispose();
    },
  );

  test(
    'dispose waits for an active recovery read and never reopens writes',
    () async {
      final repository = _DelayedReadRepository();
      var released = false;
      final resources = BootstrapResources(
        config: AppConfig.parse(),
        repository: repository,
        initialSettings: const SettingsState(),
        cleanup: [() => released = true],
      );
      final recovery = resources.recoverSettings();
      final recoveryResult = expectLater(recovery, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, 1);
      final disposal = resources.dispose();
      expect(identical(disposal, resources.dispose()), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      expect(resources.settingsQueue.isOpen, isFalse);
      repository.readResult.complete(
        const SettingsState(themeMode: ThemeMode.dark),
      );
      await recoveryResult;
      await disposal;
      expect(released, isTrue);
      expect(resources.settingsQueue.isOpen, isFalse);
      expect(resources.initialSettings, const SettingsState());
      final rejected = await resources.settingsQueue.enqueue(
        resources.settingsQueue.generation,
        () async => const SettingsWriteSuccess(SettingsState()),
      );
      expect(rejected, isA<SettingsWriteFailure>());
      await expectLater(resources.recoverSettings(), throwsStateError);
    },
  );

  test('dispose during drain prevents recovery from reading', () async {
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
    final recoveryResult = expectLater(
      resources.recoverSettings(),
      throwsStateError,
    );
    final disposal = resources.dispose();
    repository.write.complete();
    await write;
    await recoveryResult;
    await disposal;
    expect(repository.reads, 0);
    expect(queue.isOpen, isFalse);
  });

  test('dispose waits for a read that outlives recovery timeout', () async {
    final repository = _DelayedReadRepository();
    var released = false;
    final resources = BootstrapResources(
      config: AppConfig.parse(),
      repository: repository,
      initialSettings: const SettingsState(),
      cleanup: [() => released = true],
    );
    final recoveryResult = expectLater(
      resources.recoverSettings(budget: const Duration(milliseconds: 100)),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.reads, 1);
    await recoveryResult;
    final disposal = resources.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(released, isFalse);
    repository.readResult.completeError(StateError('late read error'));
    await disposal;
    expect(released, isTrue);
    expect(resources.settingsQueue.isOpen, isFalse);
  });

  test(
    'resources wait for accepted writes before releasing dependencies',
    () async {
      final repository = _DelayedRepository();
      var released = false;
      final resources = BootstrapResources(
        config: AppConfig.parse(),
        repository: repository,
        initialSettings: const SettingsState(),
        cleanup: [() => released = true],
      );
      final queue = resources.settingsQueue;
      final write = queue.enqueue(queue.generation, () async {
        await repository.writeThemeMode(ThemeMode.dark);
        return const SettingsWriteSuccess(SettingsState());
      });
      await Future<void>.delayed(Duration.zero);
      final disposal = resources.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      expect(queue.isOpen, isFalse);
      repository.write.complete();
      await write;
      await disposal;
      expect(released, isTrue);
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
        (await second as SettingsWriteFailure).failure.kind,
        AppFailureKind.cancelled,
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
      (await second as SettingsWriteFailure).failure.kind,
      AppFailureKind.cancelled,
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

  test(
    'active drain finishes accepted commands and rejects new ones',
    () async {
      final queue = SettingsCommandQueue();
      final gate = Completer<void>();
      final started = <int>[];
      Future<SettingsWriteResult> command(int number) =>
          queue.enqueue(queue.generation, () async {
            started.add(number);
            if (number == 1) await gate.future;
            return const SettingsWriteSuccess(SettingsState());
          });
      final first = command(1);
      final second = command(2);
      await Future<void>.delayed(Duration.zero);
      queue.closeForDrain();
      final rejected = await command(3);
      expect(
        (rejected as SettingsWriteFailure).failure.kind,
        AppFailureKind.cancelled,
      );
      expect(started, [1]);
      var drained = false;
      final drain = queue.drained.then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      gate.complete();
      expect(await first, isA<SettingsWriteSuccess>());
      expect(await second, isA<SettingsWriteSuccess>());
      await drain;
      expect(started, [1, 2]);
      expect(drained, isTrue);
    },
  );

  test(
    'failed in-flight write after disposal is reported before recovery reads',
    () async {
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
        retry: (count, error) => null,
      );
      final notifier = container.read(settingsProvider.notifier);
      final first = notifier.setThemeMode(ThemeMode.dark);
      final second = notifier.setLocale(const Locale('zh'));
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      final recovery = resources.recoverSettings();
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, 0);
      expect(resources.settingsQueue.isOpen, isFalse);
      repository.write.completeError(
        const AppException(AppFailure(AppFailureKind.storageWrite)),
      );
      expect(
        (await first as SettingsWriteFailure).failure.kind,
        AppFailureKind.storageWrite,
      );
      expect(
        (await second as SettingsWriteFailure).failure.kind,
        AppFailureKind.cancelled,
      );
      await recovery;
      expect(repository.reads, 1);
      expect(resources.initialSettings, const SettingsState());
      expect(resources.settingsQueue.isOpen, isTrue);
      await resources.dispose();
    },
  );

  testWidgets(
    'recovery view remains until the old write finishes and is reread',
    (tester) async {
      final repository = _DelayedRepository();
      final resources = BootstrapResources(
        config: AppConfig.parse(),
        repository: repository,
        initialSettings: const SettingsState(),
      );
      await tester.pumpWidget(TemplateApp(resources: resources));
      await tester.pumpAndSettle();
      final queue = resources.settingsQueue;
      final write = queue.enqueue(queue.generation, () async {
        await repository.writeThemeMode(ThemeMode.dark);
        return const SettingsWriteSuccess(
          SettingsState(themeMode: ThemeMode.dark),
        );
      });
      await tester.pump();
      queue.abandon(queue.generation);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(repository.reads, 0);
      repository.write.complete();
      await tester.pumpAndSettle();
      expect(await write, isA<SettingsWriteSuccess>());
      expect(repository.reads, 1);
      expect(resources.initialSettings.themeMode, ThemeMode.dark);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await resources.dispose();
    },
  );

  testWidgets('recovery timeout shows restart guidance and keeps the barrier', (
    tester,
  ) async {
    final repository = _DelayedRepository();
    final resources = BootstrapResources(
      config: AppConfig.parse(),
      repository: repository,
      initialSettings: const SettingsState(),
    );
    await tester.pumpWidget(TemplateApp(resources: resources));
    await tester.pumpAndSettle();
    final queue = resources.settingsQueue;
    final write = queue.enqueue(queue.generation, () async {
      await repository.writeThemeMode(ThemeMode.dark);
      return const SettingsWriteSuccess(SettingsState());
    });
    await tester.pump();
    queue.abandon(queue.generation);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(
      find.text('Settings recovery failed. Please restart the app.'),
      findsOneWidget,
    );
    expect(queue.isOpen, isFalse);
    expect(repository.reads, 0);
    repository.write.complete();
    await tester.pump();
    await write;
    await tester.pumpWidget(const SizedBox.shrink());
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

final class _FailingPreferences extends InMemorySharedPreferencesAsync {
  _FailingPreferences() : super.empty();
  int writes = 0;
  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async => throw Exception('read failure');
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    writes++;
    throw Exception('write failure');
  }
}

final class _DelayedReadRepository implements SettingsRepository {
  final readResult = Completer<SettingsState>();
  int reads = 0;
  @override
  Future<SettingsState> read() {
    reads++;
    return readResult.future;
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {}
  @override
  Future<void> writeLocale(Locale? locale) async {}
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
