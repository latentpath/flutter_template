import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

@immutable
final class SettingsState {
  const SettingsState({this.themeMode = ThemeMode.system, this.locale});

  final ThemeMode themeMode;
  final Locale? locale;

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    locale: clearLocale ? null : locale ?? this.locale,
  );

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.themeMode == themeMode &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(themeMode, locale);
}

abstract interface class SettingsRepository {
  Future<SettingsState> read();
  Future<void> writeThemeMode(ThemeMode value);
  Future<void> writeLocale(Locale? value);
}

class AppException implements Exception {
  const AppException();
}

final class SettingsStorageException extends AppException {
  const SettingsStorageException();
}

final class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this.value = const SettingsState()]);
  SettingsState value;
  @override
  Future<SettingsState> read() async => value;
  @override
  Future<void> writeThemeMode(ThemeMode value) async =>
      this.value = this.value.copyWith(themeMode: value);
  @override
  Future<void> writeLocale(Locale? value) async => this.value = this.value
      .copyWith(locale: value, clearLocale: value == null);
}

// The adapter exposes no plugin types to consumers of SettingsRepository.
final class PreferencesSettingsRepository implements SettingsRepository {
  PreferencesSettingsRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  static const themeKey = 'settings.theme_mode';
  static const localeKey = 'settings.locale';

  @override
  Future<SettingsState> read() async {
    final Map<String, Object?> values;
    try {
      values = await _preferences.getAll(allowList: {themeKey, localeKey});
    } on Exception {
      throw const SettingsStorageException();
    }
    final theme = switch (values[themeKey]) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = switch (values[localeKey]) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null,
    };
    if ((values[themeKey] != null &&
            !{'system', 'light', 'dark'}.contains(values[themeKey])) ||
        (values[localeKey] != null &&
            !{'system', 'zh', 'en'}.contains(values[localeKey]))) {
      debugPrint('[settings] invalid preference value; using default');
    }
    return SettingsState(themeMode: theme, locale: locale);
  }

  @override
  Future<void> writeThemeMode(ThemeMode value) => _write(themeKey, value.name);
  @override
  Future<void> writeLocale(Locale? value) =>
      _write(localeKey, value?.languageCode ?? 'system');
  Future<void> _write(String key, String value) async {
    try {
      await _preferences.setString(key, value);
    } on Exception {
      throw const SettingsStorageException();
    }
  }
}

/// Owned by the application resources, never by a notifier or repository.
final class SettingsCommandQueue {
  Future<void> _tail = Future.value();
  int _generation = 0;
  bool _open = true;
  bool _discard = false;
  void Function()? onUnexpectedDispose;

  int get generation => _generation;
  bool get isOpen => _open;
  Future<void> get drained => _tail;

  Future<SettingsWriteResult> enqueue(
    int generation,
    Future<SettingsWriteResult> Function() task,
  ) {
    if (!_open || generation != _generation) {
      return Future.value(
        const SettingsWriteFailure(SettingsFailureKind.cancelled),
      );
    }
    final result = _tail.then<SettingsWriteResult>((_) async {
      if (_discard || generation != _generation) {
        return const SettingsWriteFailure(SettingsFailureKind.cancelled);
      }
      return await task();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  void closeForDrain() {
    _open = false;
  }

  void abandon(int generation) {
    if (generation != _generation) return;
    final unexpected = _open;
    _open = false;
    _discard = true;
    if (unexpected) onUnexpectedDispose?.call();
  }

  void reopen() {
    _generation++;
    _discard = false;
    _open = true;
  }
}

enum SettingsFailureKind { storageWrite, cancelled, invalidValue }

sealed class SettingsWriteResult {
  const SettingsWriteResult();
}

final class SettingsWriteSuccess extends SettingsWriteResult {
  const SettingsWriteSuccess(this.state);
  final SettingsState state;
}

final class SettingsWriteFailure extends SettingsWriteResult {
  const SettingsWriteFailure(this.kind);
  final SettingsFailureKind kind;
}

final settingsQueueProvider = Provider<SettingsCommandQueue>(
  (ref) => SettingsCommandQueue(),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError(),
);
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(),
);
final settingsInitialStateProvider = Provider<SettingsState>(
  (ref) => const SettingsState(),
);
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

final class SettingsNotifier extends Notifier<SettingsState> {
  late SettingsCommandQueue _queue;
  late int _generation;
  @override
  SettingsState build() {
    _queue = ref.read(settingsQueueProvider);
    _generation = _queue.generation;
    if (!_queue.isOpen) throw StateError('Settings recovery is in progress');
    ref.onDispose(() => _queue.abandon(_generation));
    return ref.watch(settingsInitialStateProvider);
  }

  Future<SettingsWriteResult> setThemeMode(ThemeMode mode) =>
      _enqueue(() async {
        final candidate = state.copyWith(themeMode: mode);
        try {
          await ref.read(settingsRepositoryProvider).writeThemeMode(mode);
        } on AppException {
          debugPrint('[settings] theme write failed');
          return const SettingsWriteFailure(SettingsFailureKind.storageWrite);
        }
        if (ref.mounted) state = candidate;
        return SettingsWriteSuccess(candidate);
      });

  Future<SettingsWriteResult> setLocale(Locale? locale) {
    if (locale != null &&
        (locale.languageCode != 'en' && locale.languageCode != 'zh' ||
            locale.countryCode != null && locale.countryCode != 'CN')) {
      return Future.value(
        const SettingsWriteFailure(SettingsFailureKind.invalidValue),
      );
    }
    final normalized = locale == null ? null : Locale(locale.languageCode);
    return _enqueue(() async {
      final candidate = state.copyWith(
        locale: normalized,
        clearLocale: normalized == null,
      );
      try {
        await ref.read(settingsRepositoryProvider).writeLocale(normalized);
      } on AppException {
        debugPrint('[settings] locale write failed');
        return const SettingsWriteFailure(SettingsFailureKind.storageWrite);
      }
      if (ref.mounted) state = candidate;
      return SettingsWriteSuccess(candidate);
    });
  }

  Future<SettingsWriteResult> _enqueue(
    Future<SettingsWriteResult> Function() task,
  ) => _queue.enqueue(_generation, task);
}
