import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    });

    expect(link.matched, isTrue);
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
}
