import 'package:flinku_sdk/flinku_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FlinkuLink.noMatch returns unmatched link', () {
    final link = FlinkuLink.noMatch();

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
      'params': <String, dynamic>{'id': 42},
    });

    expect(link.matched, isTrue);
    expect(link.deepLink, 'testapp://product/42');
    expect(link.slug, 'abc123');
    expect(link.params?['id'], 42);
  });
}
