import 'dart:convert';
import 'dart:io';

import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The fingerprint step asks over IPv6 and IPv4 separately on the first
/// launches, so a click recorded over one family still matches an app whose
/// default connection uses the other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response matched(String via) => http.Response(
        jsonEncode(<String, dynamic>{
          'matched': true,
          'matchType': 'fingerprint',
          'deepLink': 'myapp://via-$via',
          'slug': 'slug-$via',
          'subdomain': 'myapp',
          'params': <String, dynamic>{},
          'projectId': 'proj_1',
        }),
        200,
      );

  http.Response unmatched() => http.Response(
        jsonEncode(<String, dynamic>{'matched': false, 'matchType': 'none'}),
        200,
      );

  late List<InternetAddressType> familyCalls;
  late List<Map<String, dynamic>> familyBodies;
  late int plainCalls;

  void install({
    http.Response? v6,
    http.Response? v4,
    http.Response? plain,
  }) {
    Flinku.debugFamilyHttpPost = ({
      required family,
      required uri,
      required headers,
      required body,
      required timeout,
    }) async {
      familyCalls.add(family);
      familyBodies.add(jsonDecode(body) as Map<String, dynamic>);
      expect(uri.toString(), 'https://flku.dev/api/match');
      return family == InternetAddressType.IPv6 ? v6 : v4;
    };
    Flinku.debugHttpPost = ({
      required uri,
      required headers,
      required body,
      required timeout,
    }) async {
      plainCalls++;
      return plain ?? unmatched();
    };
    Flinku.configure(baseUrl: 'https://myapp.flku.dev');
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Flinku.debugResetForTest();
    familyCalls = [];
    familyBodies = [];
    plainCalls = 0;
  });

  tearDown(Flinku.debugResetForTest);

  test('IPv6 match is returned and IPv4 is not asked', () async {
    install(v6: matched('v6'), v4: matched('v4'));
    final link = await Flinku.match();
    expect(link?.deepLink, 'myapp://via-v6');
    expect(familyCalls, [InternetAddressType.IPv6]);
    expect(plainCalls, 0);
    expect(familyBodies.single['subdomain'], 'myapp');
    expect(familyBodies.single['userAgent'], startsWith('flutter/'));
  });

  test('click recorded over IPv4 matches when IPv6 says no match', () async {
    install(v6: unmatched(), v4: matched('v4'));
    final link = await Flinku.match();
    expect(link?.deepLink, 'myapp://via-v4');
    expect(familyCalls, [InternetAddressType.IPv6, InternetAddressType.IPv4]);
    expect(plainCalls, 0);
  });

  test('click recorded over IPv6 matches when IPv4 is unreachable', () async {
    install(v6: matched('v6'), v4: null);
    final link = await Flinku.match();
    expect(link?.deepLink, 'myapp://via-v6');
  });

  test('IPv6 unreachable falls through to IPv4', () async {
    install(v6: null, v4: matched('v4'));
    final link = await Flinku.match();
    expect(link?.deepLink, 'myapp://via-v4');
    expect(familyCalls, [InternetAddressType.IPv6, InternetAddressType.IPv4]);
    expect(plainCalls, 0);
  });

  test('both families answer no match: default request is not repeated', () async {
    install(v6: unmatched(), v4: unmatched());
    final link = await Flinku.match();
    expect(link, isNull);
    expect(familyCalls, hasLength(2));
    expect(plainCalls, 0);
  });

  test('neither family reachable falls back to the default request', () async {
    install(v6: null, v4: null, plain: matched('plain'));
    final link = await Flinku.match();
    expect(link?.deepLink, 'myapp://via-plain');
    expect(familyCalls, hasLength(2));
    expect(plainCalls, 1);
  });

  test('a matched result is stored and later launches make no request', () async {
    install(v6: unmatched(), v4: matched('v4'));
    await Flinku.match();
    familyCalls.clear();
    final again = await Flinku.match();
    expect(again?.deepLink, 'myapp://via-v4');
    expect(familyCalls, isEmpty);
    expect(plainCalls, 0);
  });

  test('family attempts stop after five launches', () async {
    install(v6: unmatched(), v4: unmatched());
    for (var i = 0; i < 5; i++) {
      await Flinku.match();
    }
    expect(familyCalls, hasLength(10));
    expect(plainCalls, 0);
    await Flinku.match();
    expect(familyCalls, hasLength(10));
    expect(plainCalls, 1);
  });

  test('family attempts stop 24 hours after the first attempt', () async {
    final old = DateTime.now().subtract(const Duration(hours: 25));
    SharedPreferences.setMockInitialValues({
      'flinku_first_match_attempt_ms': old.millisecondsSinceEpoch,
    });
    install(v6: matched('v6'), v4: matched('v4'), plain: unmatched());
    final link = await Flinku.match();
    expect(link, isNull);
    expect(familyCalls, isEmpty);
    expect(plainCalls, 1);
  });

  test('tests that only set debugHttpPost keep the single request path', () async {
    var calls = 0;
    Flinku.debugHttpPost = ({
      required uri,
      required headers,
      required body,
      required timeout,
    }) async {
      calls++;
      return unmatched();
    };
    Flinku.configure(baseUrl: 'https://myapp.flku.dev');
    await Flinku.match();
    expect(calls, 1);
  });

  test('resetAll clears the attempt bookkeeping', () async {
    install(v6: unmatched(), v4: unmatched());
    for (var i = 0; i < 6; i++) {
      await Flinku.match();
    }
    expect(plainCalls, 1);
    await Flinku.resetAll();
    await Flinku.match();
    expect(familyCalls, hasLength(12));
    expect(plainCalls, 1);
  });
}
