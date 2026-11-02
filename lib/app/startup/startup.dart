import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_config.dart';
import '../settings/settings.dart';
import 'bootstrap_resources.dart';

export 'bootstrap_resources.dart';

enum StartupFailureKind { configuration, dependency, timeout, busy }

abstract interface class Bootstrap {
  Future<BootstrapResources> load();
}

final class DefaultBootstrap implements Bootstrap {
  DefaultBootstrap({
    required this.configLoader,
    required this.repositoryFactory,
    this.preferenceBudget = const Duration(seconds: 2),
  });
  final AppConfig Function() configLoader;
  final SettingsRepository Function() repositoryFactory;
  final Duration preferenceBudget;

  @override
  Future<BootstrapResources> load() async {
    final config = configLoader();
    final repository = repositoryFactory();
    SettingsState snapshot = const SettingsState();
    try {
      snapshot = await repository.read().timeout(preferenceBudget);
      if (snapshot.locale != null) {
        if (!{'en', 'zh'}.contains(snapshot.locale!.languageCode)) {
          snapshot = snapshot.copyWith(clearLocale: true);
        } else {
          snapshot = snapshot.copyWith(
            locale: Locale(snapshot.locale!.languageCode),
          );
        }
      }
      if (!{
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      }.contains(snapshot.themeMode)) {
        snapshot = const SettingsState();
      }
    } catch (_) {
      // Unavailable preferences fall back to system defaults without overwriting storage.
      debugPrint('[startup] preferences unavailable; using system defaults');
    }
    return BootstrapResources(
      config: config,
      repository: repository,
      initialSettings: snapshot,
    );
  }
}

final class StartupCoordinator extends StatefulWidget {
  const StartupCoordinator({
    super.key,
    required this.bootstrap,
    this.startupBudget = const Duration(seconds: 5),
  });
  final Bootstrap bootstrap;
  final Duration startupBudget;
  @override
  State<StartupCoordinator> createState() => _StartupCoordinatorState();
}

final class _StartupCoordinatorState extends State<StartupCoordinator> {
  BootstrapResources? _resources;
  StartupFailureKind? _failure;
  bool _loading = true;
  bool _inFlight = false;
  bool _underlyingRunning = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_inFlight) return;
    if (_underlyingRunning) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = StartupFailureKind.busy;
        });
      }
      return;
    }
    _inFlight = true;
    final attempt = ++_attempt;
    setState(() {
      _loading = true;
      _failure = null;
    });
    var transferred = false;
    var expired = false;
    try {
      final future = widget.bootstrap.load();
      _underlyingRunning = true;
      // Observe even late failures. A late successful resource belongs to this expired attempt.
      future.then(
        (resource) async {
          if (expired || _attempt != attempt || !mounted) {
            await resource.dispose();
          }
          _underlyingRunning = false;
          if (mounted && _attempt == attempt) setState(() {});
        },
        onError: (Object _) {
          _underlyingRunning = false;
          debugPrint('[startup] expired bootstrap attempt failed');
          if (mounted && _attempt == attempt) setState(() {});
        },
      );
      final resources = await future.timeout(widget.startupBudget);
      if (!mounted || _attempt != attempt) {
        await resources.dispose();
        return;
      }
      _resources = resources;
      transferred = true;
      setState(() {
        _loading = false;
      });
    } on FormatException {
      debugPrint('[startup] configuration rejected');
      if (mounted && _attempt == attempt) {
        setState(() {
          _loading = false;
          _failure = StartupFailureKind.configuration;
        });
      }
    } on TimeoutException {
      debugPrint('[startup] initialization budget exceeded');
      expired = true;
      if (mounted && _attempt == attempt) {
        setState(() {
          _loading = false;
          _failure = StartupFailureKind.timeout;
        });
      }
    } catch (_) {
      debugPrint('[startup] required dependency initialization failed');
      if (mounted && _attempt == attempt) {
        setState(() {
          _loading = false;
          _failure = StartupFailureKind.dependency;
        });
      }
    } finally {
      if (_attempt == attempt) _inFlight = false;
      if (!transferred && _attempt == attempt && mounted && _loading) {
        setState(() {
          _loading = false;
          _failure = StartupFailureKind.dependency;
        });
      }
    }
  }

  @override
  void dispose() {
    ++_attempt;
    final resources = _resources;
    if (resources != null) unawaited(resources.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resources = _resources;
    if (resources != null) return TemplateApp(resources: resources);
    if (_loading) return const _NeutralStartupView();
    return _StartupFailureView(
      kind: _failure ?? StartupFailureKind.dependency,
      retry: _start,
      busy: _inFlight || _underlyingRunning,
    );
  }
}

class _NeutralStartupView extends StatelessWidget {
  const _NeutralStartupView();
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: CircularProgressIndicator())),
  );
}

class _StartupFailureView extends StatelessWidget {
  const _StartupFailureView({
    required this.kind,
    required this.retry,
    required this.busy,
  });
  final StartupFailureKind kind;
  final Future<void> Function() retry;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final zh =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';
    final message = switch (kind) {
      StartupFailureKind.configuration =>
        zh ? '应用配置无效。' : 'The app configuration is invalid.',
      StartupFailureKind.timeout =>
        zh
            ? '启动耗时过长，请稍后重试或重启应用。'
            : 'Startup took too long. Wait and retry, or restart the app.',
      StartupFailureKind.busy =>
        zh
            ? '启动仍在进行，请等待或重启应用。'
            : 'Startup is still running. Wait or restart the app.',
      StartupFailureKind.dependency =>
        zh ? '应用暂时无法启动。' : 'The app could not start.',
    };
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : retry,
                  child: Text(zh ? '重试' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
