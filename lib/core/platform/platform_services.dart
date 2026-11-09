import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final class AppInfo {
  const AppInfo(this.name, this.version, this.buildNumber);
  final String name;
  final String version;
  final String buildNumber;
}

abstract interface class AppInfoReader {
  Future<AppInfo?> read();
}

final class PackageAppInfoReader implements AppInfoReader {
  PackageAppInfoReader({Future<PackageInfo> Function()? load})
    : _load = load ?? (() => PackageInfo.fromPlatform());
  final Future<PackageInfo> Function() _load;
  @override
  Future<AppInfo?> read() async {
    try {
      final info = await _load();
      return AppInfo(info.appName, info.version, info.buildNumber);
    } catch (_) {
      return null;
    }
  }
}

enum ExternalLinkResult { opened, unavailable, failed, rejected }

final class ExternalLinkOpener {
  ExternalLinkOpener({Future<bool> Function(Uri)? launch})
    : _launch =
          launch ??
          ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final Future<bool> Function(Uri) _launch;

  Future<ExternalLinkResult> open(Uri uri) async {
    if (uri.scheme != 'https' ||
        uri.host != 'flutter.dev' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.hasPort) {
      return ExternalLinkResult.rejected;
    }
    try {
      return await _launch(uri)
          ? ExternalLinkResult.opened
          : ExternalLinkResult.unavailable;
    } catch (_) {
      return ExternalLinkResult.failed;
    }
  }
}
