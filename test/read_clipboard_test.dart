import 'dart:convert';

import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response unmatched() => http.Response(
        jsonEncode(<String, dynamic>{'matched': false, 'matchType': 'none'}),
        200,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Flinku.debugResetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    Flinku.debugResetForTest();
  });

  test('readClipboard false never accesses Clipboard.getData or setData',
      () async {
    final clipboardMethods = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData' ||
          call.method == 'Clipboard.setData') {
        clipboardMethods.add(call.method);
      }
      return null;
    });

    Flinku.debugFamilyHttpPost = ({
      required family,
      required uri,
      required headers,
      required body,
      required timeout,
    }) async =>
        unmatched();

    Flinku.debugHttpPost = ({
      required uri,
      required headers,
      required body,
      required timeout,
    }) async =>
        unmatched();

    Flinku.configure(
      baseUrl: 'https://myapp.flku.dev',
      readClipboard: false,
    );
    final link = await Flinku.match();

    expect(link, isNull);
    expect(clipboardMethods, isEmpty);
  });

  test('readClipboard true may call Clipboard.getData after fingerprint miss',
      () async {
    final clipboardMethods = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        clipboardMethods.add(call.method);
        return <String, dynamic>{'text': 'https://myapp.flku.dev/promo'};
      }
      if (call.method == 'Clipboard.setData') {
        clipboardMethods.add(call.method);
        return null;
      }
      return null;
    });

    Flinku.debugFamilyHttpPost = ({
      required family,
      required uri,
      required headers,
      required body,
      required timeout,
    }) async =>
        unmatched();

    Flinku.debugHttpPost = ({
      required uri,
      required headers,
      required body,
      required timeout,
    }) async {
      final map = jsonDecode(body) as Map<String, dynamic>;
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
      return unmatched();
    };

    Flinku.configure(baseUrl: 'https://myapp.flku.dev');
    final link = await Flinku.match();

    expect(clipboardMethods, contains('Clipboard.getData'));
    expect(link?.matchType, 'clipboard');
  });
}
