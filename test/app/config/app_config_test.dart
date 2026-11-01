import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/app/config/app_config.dart';

void main() {
  test('defaults to development and fake without a URL', () {
    final config = AppConfig.parse();
    expect(config.environment, AppEnvironment.development);
    expect(config.dataSourceMode, DataSourceMode.fake);
    expect(config.apiBaseUri, isNull);
  });

  for (final environment in AppEnvironment.values) {
    test('${environment.name} defaults to offline fake mode', () {
      final config = AppConfig.parse(appEnv: environment.name);
      expect(config.environment, environment);
      expect(config.dataSourceMode, DataSourceMode.fake);
      expect(config.apiBaseUri, isNull);
    });
  }

  test('rejects unknown environment and data source mode', () {
    expect(() => AppConfig.parse(appEnv: 'prod'), throwsFormatException);
    expect(
      () => AppConfig.parse(dataSourceMode: 'other'),
      throwsFormatException,
    );
  });

  test('rejects an address in fake mode', () {
    expect(
      () => AppConfig.parse(apiBaseUri: 'https://service.acme.dev/'),
      throwsFormatException,
    );
  });

  test('accepts a valid HTTPS API address', () {
    final config = AppConfig.parse(
      dataSourceMode: 'api',
      apiBaseUri: 'https://service.acme.dev/v1/',
    );
    expect(config.apiBaseUri, Uri.parse('https://service.acme.dev/v1/'));
  });

  for (final address in [
    '',
    'http://service.acme.dev/',
    'https://example.com/',
    'https://<host>/',
    'https://user:pass@service.acme.dev/',
    'https://service.acme.dev/?token=x',
    'https://service.acme.dev/#fragment',
  ]) {
    test('rejects invalid API address: $address', () {
      expect(
        () => AppConfig.parse(dataSourceMode: 'api', apiBaseUri: address),
        throwsFormatException,
      );
    });
  }
}
