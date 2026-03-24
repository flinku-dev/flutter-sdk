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
}
