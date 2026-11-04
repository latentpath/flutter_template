import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/errors/app_failure.dart';
import '../l10n/generated/app_localizations.dart';
import '../features/example/example_page.dart';
import '../core/platform/platform_services.dart';
import 'settings/settings.dart';
import 'startup/bootstrap_resources.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const settings = '/settings';
  static const example = '/example';
}

class TemplateApp extends StatefulWidget {
  const TemplateApp({
    super.key,
    required this.resources,
    this.initialLocation = AppRoutes.home,
  });
  final BootstrapResources resources;
  final String initialLocation;
  @override
  State<TemplateApp> createState() => _TemplateAppState();
}

class _TemplateAppState extends State<TemplateApp> {
  bool _recovering = false;
  bool _recoveryFailed = false;
  int _scopeGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.resources.settingsQueue.onUnexpectedDispose = () {
      if (mounted) scheduleMicrotask(_recover);
    };
  }

  Future<void> _recover() async {
    if (!mounted || _recovering) return;
    setState(() {
      _recovering = true;
      _recoveryFailed = false;
    });
    try {
      await widget.resources.recoverSettings();
      if (mounted) {
        setState(() {
          _scopeGeneration++;
          _recovering = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recovering = false;
          _recoveryFailed = true;
        });
      }
    }
  }

  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.example,
        builder: (context, state) => const ExamplePage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
  @override
  void dispose() {
    widget.resources.settingsQueue.onUnexpectedDispose = null;
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering || _recoveryFailed) {
      final zh =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
          'zh';
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: _recovering
                ? const CircularProgressIndicator()
                : Text(
                    zh
                        ? '设置恢复失败，请重启应用。'
                        : 'Settings recovery failed. Please restart the app.',
                  ),
          ),
        ),
      );
    }
    return ProviderScope(
      key: ValueKey(_scopeGeneration),
      retry: (retryCount, error) => null,
      overrides: [
        exampleLoggerProvider.overrideWithValue(widget.resources.logger),
        exampleRepositoryProvider.overrideWith(
          (ref) => widget.resources.exampleClient.repository,
        ),
        settingsQueueProvider.overrideWithValue(widget.resources.settingsQueue),
        settingsRepositoryProvider.overrideWithValue(
          widget.resources.repository,
        ),
        appConfigProvider.overrideWithValue(widget.resources.config),
        settingsInitialStateProvider.overrideWithValue(
          widget.resources.initialSettings,
        ),
      ],
      child: _AppRouter(router: _router),
    );
  }
}

class _AppRouter extends ConsumerWidget {
  const _AppRouter({required this.router});
  final GoRouter router;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final light = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: light,
      darkTheme: dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.homeTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48)
                  .clamp(0.0, double.infinity)
                  .toDouble(),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.homeMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.push(AppRoutes.example),
                  child: Text(l.exampleTitle),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: const Icon(Icons.settings),
                  label: Text(l.openSettings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final appInfoReaderProvider = Provider<AppInfoReader>(
  (ref) => PackageAppInfoReader(),
);
final appInfoProvider = FutureProvider<AppInfo?>(
  (ref) => ref.watch(appInfoReaderProvider).read(),
);
final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => ExternalLinkOpener(),
);

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _saving = false;
  Future<void> _save(Future<SettingsWriteResult> Function() action) async {
    setState(() => _saving = true);
    final SettingsWriteResult result;
    try {
      result = await action();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is SettingsWriteFailure &&
        result.failure.kind != AppFailureKind.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsTitle),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.themeLabel, style: Theme.of(context).textTheme.titleMedium),
          if (_saving) const LinearProgressIndicator(),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) {
              if (!_saving && value != null) {
                _save(() => notifier.setThemeMode(value));
              }
            },
            child: Column(
              children: [
                for (final entry in [
                  (ThemeMode.system, l.systemOption),
                  (ThemeMode.light, l.lightOption),
                  (ThemeMode.dark, l.darkOption),
                ])
                  RadioListTile<ThemeMode>(
                    value: entry.$1,
                    title: Text(entry.$2),
                  ),
              ],
            ),
          ),
          const Divider(),
          Text(l.languageLabel, style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<Locale?>(
            groupValue: settings.locale,
            onChanged: (value) {
              if (!_saving) {
                _save(() => notifier.setLocale(value));
              }
            },
            child: Column(
              children: [
                for (final entry in <(Locale?, String)>[
                  (null, l.systemOption),
                  (const Locale('zh'), l.chineseOption),
                  (const Locale('en'), l.englishOption),
                ])
                  RadioListTile<Locale?>(
                    value: entry.$1,
                    title: Text(entry.$2),
                  ),
              ],
            ),
          ),
          const Divider(),
          ref
              .watch(appInfoProvider)
              .when(
                data: (info) => Text(
                  info == null
                      ? l.appInfoUnavailable
                      : '${info.name} ${info.version} (${info.buildNumber})',
                ),
                loading: () => Text(l.loading),
                error: (_, _) => Text(l.appInfoUnavailable),
              ),
          TextButton(
            onPressed: () async {
              final result = await ref
                  .read(externalLinkOpenerProvider)
                  .open(Uri.parse('https://flutter.dev'));
              if (context.mounted && result != ExternalLinkResult.opened) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.linkFailed)));
              }
            },
            child: Text(l.openWebsite),
          ),
        ],
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.notFoundTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.notFoundMessage),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l.backHome),
            ),
          ],
        ),
      ),
    );
  }
}
