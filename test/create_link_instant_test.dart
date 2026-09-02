import 'dart:convert';

import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseUrl = 'https://yourapp.flku.dev';
  const apiKey = 'flk_pk_test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Flinku.debugInstantHttpPost = null;
    Flinku.configure(baseUrl: baseUrl, apiKey: apiKey, debug: true);
  });

  tearDown(() {
    Flinku.debugInstantHttpPost = null;
  });

  Future<void> pumpRetries() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  test('retries 500 then succeeds without logging', () async {
    var calls = 0;
    Flinku.debugInstantHttpPost = ({
      required uri,
      required headers,
      required body,
    }) async {
      calls += 1;
      if (calls == 1) {
        return http.Response('err', 500);
      }
      return http.Response(jsonEncode({'id': '1', 'slug': 'x'}), 201);
    };

    Flinku.createLinkInstant(
      FlinkuLinkOptions(title: 'Test', deepLink: 'app://x'),
    );
    await pumpRetries();
    expect(calls, 2);
  });

  test('does not retry 403', () async {
    var calls = 0;
    Flinku.debugInstantHttpPost = ({
      required uri,
      required headers,
      required body,
    }) async {
      calls += 1;
      return http.Response(jsonEncode({'error': 'Forbidden'}), 403);
    };

    Flinku.createLinkInstant(
      FlinkuLinkOptions(title: 'Test', deepLink: 'app://x'),
    );
    await pumpRetries();
    expect(calls, 1);
  });

  test('does not retry 409', () async {
    var calls = 0;
    Flinku.debugInstantHttpPost = ({
      required uri,
      required headers,
      required body,
    }) async {
      calls += 1;
      return http.Response(jsonEncode({'error': 'Slug already in use'}), 409);
    };

    Flinku.createLinkInstant(
      FlinkuLinkOptions(title: 'Test', deepLink: 'app://x'),
    );
    await pumpRetries();
    expect(calls, 1);
  });
}
