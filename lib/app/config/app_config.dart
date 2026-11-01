enum AppEnvironment { development, staging, production }

enum DataSourceMode { fake, api }

/// Public build configuration. Never put secrets in dart-defines.
final class AppConfig {
  const AppConfig._(this.environment, this.dataSourceMode, this.apiBaseUri);

  final AppEnvironment environment;
  final DataSourceMode dataSourceMode;
  final Uri? apiBaseUri;

  factory AppConfig.fromEnvironment() => AppConfig.parse(
    appEnv: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    dataSourceMode: const String.fromEnvironment(
      'DATA_SOURCE_MODE',
      defaultValue: 'fake',
    ),
    apiBaseUri: const String.fromEnvironment('API_BASE_URI'),
  );

  factory AppConfig.parse({
    String appEnv = 'development',
    String dataSourceMode = 'fake',
    String apiBaseUri = '',
  }) {
    final environment = switch (appEnv) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw const FormatException('Invalid APP_ENV'),
    };
    final mode = switch (dataSourceMode) {
      'fake' => DataSourceMode.fake,
      'api' => DataSourceMode.api,
      _ => throw const FormatException('Invalid DATA_SOURCE_MODE'),
    };
    if (mode == DataSourceMode.fake) {
      if (apiBaseUri.isNotEmpty) {
        throw const FormatException('API_BASE_URI must be empty in fake mode');
      }
      return AppConfig._(environment, mode, null);
    }
    final uri = Uri.tryParse(apiBaseUri);
    final host = uri?.host.toLowerCase() ?? '';
    final placeholder =
        host == 'localhost' ||
        host == 'example.com' ||
        host.endsWith('.example.com') ||
        host == 'example.org' ||
        host.endsWith('.example.org') ||
        host == 'example.net' ||
        host.endsWith('.example.net') ||
        host.endsWith('.example') ||
        host.endsWith('.invalid') ||
        host.endsWith('.test');
    if (uri == null ||
        uri.scheme != 'https' ||
        host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        apiBaseUri.trim() != apiBaseUri ||
        placeholder ||
        apiBaseUri.contains('<') ||
        apiBaseUri.contains('>')) {
      throw const FormatException('Invalid API_BASE_URI');
    }
    return AppConfig._(environment, mode, uri);
  }
}
