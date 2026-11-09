import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_template/core/platform/platform_services.dart';

void main() {
  test('external links are restricted and results stay explicit', () async {
    var calls = 0;
    final opener = ExternalLinkOpener(
      launch: (_) async {
        calls++;
        return false;
      },
    );
    expect(
      await opener.open(Uri.parse('https://evil.test')),
      ExternalLinkResult.rejected,
    );
    expect(
      await opener.open(Uri.parse('https://flutter.dev/?token=secret')),
      ExternalLinkResult.rejected,
    );
    expect(calls, 0);
    expect(
      await opener.open(Uri.parse('https://flutter.dev')),
      ExternalLinkResult.unavailable,
    );
    expect(calls, 1);
    expect(
      await ExternalLinkOpener(launch: (_) async => true)
          .open(Uri.parse('https://flutter.dev')),
      ExternalLinkResult.opened,
    );
    expect(
      await ExternalLinkOpener(launch: (_) async => throw StateError('secret'))
          .open(Uri.parse('https://flutter.dev')),
      ExternalLinkResult.failed,
    );
  });
}
