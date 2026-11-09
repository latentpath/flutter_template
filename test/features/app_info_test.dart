import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_template/app/settings/settings.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/app.dart';
import 'package:flutter_template/core/platform/platform_services.dart';
import 'package:package_info_plus/package_info_plus.dart';

final class FakeReader implements AppInfoReader {
  FakeReader(this.result);
  final AppInfo? result;
  @override
  Future<AppInfo?> read() async => result;
}

void main() {
  test(
    'app info provider accepts successful and unavailable readers',
    () async {
      for (final info in [const AppInfo('Example', '1.2.3', '4'), null]) {
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appInfoReaderProvider.overrideWithValue(FakeReader(info)),
          ],
        );
        addTearDown(container.dispose);
        expect(await container.read(appInfoProvider.future), same(info));
      }
    },
  );
  test(
    'package info adapter maps success and handles plugin failure',
    () async {
      final reader = PackageAppInfoReader(
        load: () async => PackageInfo(
          appName: 'Example',
          packageName: 'id',
          version: '1.2.3',
          buildNumber: '4',
        ),
      );
      final info = await reader.read();
      expect(
        (info!.name, info.version, info.buildNumber),
        ('Example', '1.2.3', '4'),
      );
      expect(
        await PackageAppInfoReader(
          load: () async => throw StateError('secret-token'),
        ).read(),
        isNull,
      );
    },
  );
  testWidgets('settings displays information and external link failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          settingsQueueProvider.overrideWithValue(SettingsCommandQueue()),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
          settingsInitialStateProvider.overrideWithValue(const SettingsState()),
          appInfoReaderProvider.overrideWithValue(
            FakeReader(const AppInfo('Example', '1.2.3', '4')),
          ),
          externalLinkOpenerProvider.overrideWithValue(
            ExternalLinkOpener(launch: (_) async => false),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example 1.2.3 (4)'), findsOneWidget);
    await tester.ensureVisible(find.text('Open Flutter website'));
    await tester.tap(find.text('Open Flutter website'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the link.'), findsOneWidget);
  });
}
