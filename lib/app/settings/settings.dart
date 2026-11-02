import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final class SettingsStorageException implements Exception {
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
  Future<void> _tail = Future<void>.value();
  @override
  SettingsState build() => ref.watch(settingsInitialStateProvider);

  Future<SettingsWriteResult> setThemeMode(ThemeMode mode) =>
      _enqueue(() async {
        try {
          await ref.read(settingsRepositoryProvider).writeThemeMode(mode);
        } on SettingsStorageException {
          debugPrint('[settings] theme write failed');
          return const SettingsWriteFailure(SettingsFailureKind.storageWrite);
        }
        state = state.copyWith(themeMode: mode);
        return SettingsWriteSuccess(state);
      });

  Future<SettingsWriteResult> setLocale(Locale? locale) {
    if (locale != null &&
        (locale.languageCode != 'en' && locale.languageCode != 'zh' ||
            locale.countryCode != null && locale.countryCode != 'CN')) {
      return Future.value(
        const SettingsWriteFailure(SettingsFailureKind.invalidValue),
      );
    }
    return _enqueue(() async {
      try {
        await ref.read(settingsRepositoryProvider).writeLocale(locale);
      } on SettingsStorageException {
        debugPrint('[settings] locale write failed');
        return const SettingsWriteFailure(SettingsFailureKind.storageWrite);
      }
      state = state.copyWith(locale: locale, clearLocale: locale == null);
      return SettingsWriteSuccess(state);
    });
  }

  Future<SettingsWriteResult> _enqueue(
    Future<SettingsWriteResult> Function() task,
  ) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
