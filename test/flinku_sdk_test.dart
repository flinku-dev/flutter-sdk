import 'dart:convert';

import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flinku_sdk/install_referrer');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Flinku.debugResetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    Flinku.debugResetForTest();
  });

  test('FlinkuLink.notMatched returns unmatched link', () {
    final link = FlinkuLink.notMatched();

    expect(link.matched, isFalse);
    expect(link.deepLink, isNull);
    expect(link.params, isNull);
    expect(link.slug, isNull);
  });

  test('FlinkuLink.fromJson parses payload', () {
    final link = FlinkuLink.fromJson(<String, dynamic>{
      'matched': true,
      'deepLink': 'testapp://product/42',
      'slug': 'abc123',
      'subdomain': 'yourapp',
      'title': 'Promo',
      'params': <String, dynamic>{'id': 42},
      'clickedAt': '2026-01-15T12:00:00.000Z',
      'projectId': 'proj_1',
      'matchType': 'fingerprint',
    });

    expect(link.matched, isTrue);
    expect(link.matchType, 'fingerprint');
    expect(link.deepLink, 'testapp://product/42');
    expect(link.slug, 'abc123');
    expect(link.subdomain, 'yourapp');
    expect(link.title, 'Promo');
    expect(link.params?['id'], 42);
    expect(link.clickedAt, isNotNull);
    expect(link.projectId, 'proj_1');
  });

  test('FlinkuConfig extracts subdomain from baseUrl', () {
    const config = FlinkuConfig(baseUrl: 'https://yourapp.flku.dev');
    expect(config.subdomain, 'yourapp');
  });

  test('FlinkuLinkOptions.toJson omits nulls and serializes dates', () {
    final json = FlinkuLinkOptions(
      title: 'Sale',
      deepLink: 'myapp://deal',
      params: const {'ref': 'x'},
      expiresAt: DateTime.utc(2026, 6, 1),
    ).toJson();

    expect(json['title'], 'Sale');
    expect(json['deepLink'], 'myapp://deal');
    expect(json['params'], const {'ref': 'x'});
    expect(json['expiresAt'], '2026-06-01T00:00:00.000Z');
    expect(json.containsKey('slug'), isFalse);
  });

  test('FlinkuCreatedLink.fromJson parses response', () {
    final link = FlinkuCreatedLink.fromJson(<String, dynamic>{
      'id': 'l_1',
      'slug': 'abc',
      'shortUrl': 'https://flku.dev/abc',
      'deepLink': 'myapp://x',
      'params': <String, dynamic>{'a': 1},
    });

    expect(link.id, 'l_1');
    expect(link.slug, 'abc');
    expect(link.shortUrl, 'https://flku.dev/abc');
    expect(link.deepLink, 'myapp://x');
    expect(link.params, {'a': '1'});
  });

  group('Play Install Referrer match', () {
    http.Response matchedReferrerResponse() {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'matched': true,
          'matchType': 'referrer',
          'deepLink': 'myapp://from-referrer',
          'slug': 'ref-slug',
          'subdomain': 'myapp',
          'params': <String, dynamic>{},
          'projectId': 'proj_ref',
        }),
        200,
      );
    }

    http.Response unmatchedResponse() {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'matched': false,
          'matchType': 'none',
        }),
        200,
      );
    }

    test('referrer present and valid posts referrer and returns match', () async {
      Flinku.debugIsAndroid = () => true;
      final bodies = <Map<String, dynamic>>[];
      var channelCalls = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        channelCalls++;
        expect(call.method, 'getInstallReferrer');
        return 'flinku_click=click_abc&utm_source=play';
      });

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        bodies.add(jsonDecode(body) as Map<String, dynamic>);
        return matchedReferrerResponse();
      };

      Flinku.configure(baseUrl: 'https://myapp.flku.dev');
      final link = await Flinku.match();

      expect(channelCalls, 1);
      expect(bodies, hasLength(1));
      expect(bodies.first['referrer'], 'flinku_click=click_abc&utm_source=play');
      expect(bodies.first['subdomain'], 'myapp');
      expect(bodies.first.containsKey('clipboardUrl'), isFalse);
      expect(bodies.first.containsKey('userAgent'), isFalse);
      expect(link, isNotNull);
      expect(link!.matchType, 'referrer');
      expect(link.deepLink, 'myapp://from-referrer');
    });

    test('referrer present without flinku_click falls through to fingerprint',
        () async {
      Flinku.debugIsAndroid = () => true;
      final bodies = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return 'utm_source=google-play&utm_medium=organic';
      });

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        bodies.add(jsonDecode(body) as Map<String, dynamic>);
        return unmatchedResponse();
      };

      Flinku.configure(baseUrl: 'https://myapp.flku.dev');
      final link = await Flinku.match();

      expect(link, isNull);
      expect(bodies, isNotEmpty);
      expect(bodies.first.containsKey('referrer'), isFalse);
      expect(bodies.first['userAgent'], startsWith('flutter/'));
    });

    test('channel returns null falls through to fingerprint', () async {
      Flinku.debugIsAndroid = () => true;
      final bodies = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        bodies.add(jsonDecode(body) as Map<String, dynamic>);
        return unmatchedResponse();
      };

      Flinku.configure(baseUrl: 'https://myapp.flku.dev');
      await Flinku.match();

      expect(bodies, isNotEmpty);
      expect(bodies.first.containsKey('referrer'), isFalse);
      expect(bodies.first['userAgent'], startsWith('flutter/'));
    });

    test('channel throws falls through to fingerprint', () async {
      Flinku.debugIsAndroid = () => true;
      final bodies = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'fail');
      });

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        bodies.add(jsonDecode(body) as Map<String, dynamic>);
        return unmatchedResponse();
      };

      Flinku.configure(baseUrl: 'https://myapp.flku.dev');
      final link = await Flinku.match();

      expect(link, isNull);
      expect(bodies, isNotEmpty);
      expect(bodies.first.containsKey('referrer'), isFalse);
      expect(bodies.first['userAgent'], startsWith('flutter/'));
    });

    test('iOS path skips install referrer channel', () async {
      Flinku.debugIsAndroid = () => false;
      var channelCalls = 0;
      final bodies = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        channelCalls++;
        return 'flinku_click=should_not_be_used';
      });

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        bodies.add(jsonDecode(body) as Map<String, dynamic>);
        return unmatchedResponse();
      };

      Flinku.configure(baseUrl: 'https://myapp.flku.dev');
      await Flinku.match();

      expect(channelCalls, 0);
      expect(bodies, isNotEmpty);
      expect(bodies.first.containsKey('referrer'), isFalse);
      expect(bodies.first['userAgent'], startsWith('flutter/'));
    });

    test('referrer match succeeds with customDomain configured', () async {
      Flinku.debugIsAndroid = () => true;
      final bodies = <Map<String, dynamic>>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return 'flinku_click=click_custom&utm_source=play';
      });

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        bodies.add(jsonDecode(body) as Map<String, dynamic>);
        return matchedReferrerResponse();
      };

      Flinku.configure(
        baseUrl: 'https://myapp.flku.dev',
        customDomain: 'go.example.com',
      );
      final link = await Flinku.match();

      expect(bodies, hasLength(1));
      expect(bodies.first['referrer'], 'flinku_click=click_custom&utm_source=play');
      expect(bodies.first['subdomain'], 'myapp');
      expect(bodies.first.containsKey('clipboardUrl'), isFalse);
      expect(bodies.first.containsKey('customDomain'), isFalse);
      expect(link, isNotNull);
      expect(link!.matchType, 'referrer');
    });

    test(
        'clipboard customDomain match when referrer also present but lacks flinku_click',
        () async {
      Flinku.debugIsAndroid = () => true;
      final bodies = <Map<String, dynamic>>[];
      const clipUrl = 'https://go.example.com/promo';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return 'utm_source=google-play&utm_medium=organic';
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipUrl};
        }
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      });

      Flinku.debugHttpPost = ({
        required uri,
        required headers,
        required body,
        required timeout,
      }) async {
        final map = jsonDecode(body) as Map<String, dynamic>;
        bodies.add(map);
        if (map.containsKey('clipboardUrl')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'matched': true,
              'matchType': 'clipboard',
              'deepLink': 'myapp://from-clipboard',
              'slug': 'promo',
              'subdomain': 'myapp',
              'params': <String, dynamic>{},
              'projectId': 'proj_clip',
            }),
            200,
          );
        }
        return unmatchedResponse();
      };

      Flinku.configure(
        baseUrl: 'https://myapp.flku.dev',
        customDomain: 'go.example.com',
      );
      final link = await Flinku.match();

      expect(link, isNotNull);
      expect(link!.matchType, 'clipboard');
      expect(link.deepLink, 'myapp://from-clipboard');
      expect(bodies.any((b) => b['clipboardUrl'] == clipUrl), isTrue);
      expect(bodies.any((b) => b.containsKey('referrer')), isFalse);
    });
  });
}
