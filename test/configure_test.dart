import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseProjectBaseUrl', () {
    test('accepts valid baseUrl', () {
      final parsed = parseProjectBaseUrl('https://myapp.flku.dev');
      expect(parsed.baseUrl, 'https://myapp.flku.dev');
      expect(parsed.subdomain, 'myapp');
    });

    test('accepts trailing slash', () {
      final parsed = parseProjectBaseUrl('https://myapp.flku.dev/');
      expect(parsed.baseUrl, 'https://myapp.flku.dev');
      expect(parsed.subdomain, 'myapp');
    });

    test('rejects invalid baseUrl with exact message', () {
      expect(
        () => parseProjectBaseUrl('http://myapp.flku.dev'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          invalidBaseUrlMessage,
        )),
      );
      expect(
        () => parseProjectBaseUrl('https://flku.dev'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          invalidBaseUrlMessage,
        )),
      );
    });
  });

  group('normalizeCustomDomain', () {
    test('lowercases and strips trailing dot', () {
      expect(normalizeCustomDomain('Go.Example.COM.'), 'go.example.com');
    });

    test('rejects scheme and port', () {
      expect(
        () => normalizeCustomDomain('https://go.example.com'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => normalizeCustomDomain('go.example.com:443'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('flinkuClipboardUrlAccepted', () {
    const config = FlinkuConfig(baseUrl: 'https://yourapp.flku.dev');

    test('accepts flku.dev subdomain host', () {
      expect(
        flinkuClipboardUrlAccepted('https://yourapp.flku.dev/abc', config),
        isTrue,
      );
    });

    test('accepts custom domain when configured', () {
      const custom = FlinkuConfig(
        baseUrl: 'https://yourapp.flku.dev',
        customDomain: 'go.example.com',
      );
      expect(
        flinkuClipboardUrlAccepted('https://go.example.com/promo', custom),
        isTrue,
      );
      expect(
        flinkuClipboardUrlAccepted('https://other.example.com/x', custom),
        isFalse,
      );
    });
  });

  group('Flinku.configure', () {
    test('sets API base to flku.dev', () {
      Flinku.configure(baseUrl: 'https://yourapp.flku.dev/');
      expect(flinkuApiBaseUrl, 'https://flku.dev');
    });
  });
}
