import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'flinku_config.dart';
import 'flinku_http.dart';
import 'flinku_link.dart';

class Flinku {
  Flinku._();

  static FlinkuConfig? _config;
  static bool _hasMatched = false;
  static SharedPreferences? _prefs;

  static const String _matchedKey = 'flinku_matched';
  static const String _matchResultKey = 'flinku_match_result';

  /// Configure Flinku with your project subdomain URL.
  ///
  /// Call this once in main() before runApp():
  /// ```dart
  /// Flinku.configure(baseUrl: 'https://yourapp.flku.dev');
  /// ```
  static void configure({
    required String baseUrl,
    bool debug = false,
    Duration timeout = const Duration(seconds: 5),
  }) {
    _config = FlinkuConfig(
      baseUrl: baseUrl,
      debug: debug,
      timeout: timeout,
    );
    _log('Flinku SDK configured');
  }

  /// Returns true if Flinku.match() has already been called
  /// and a match was found. Prevents double-matching.
  static bool get hasMatched => _hasMatched;

  static Future<FlinkuLink> match() async {
    if (_config == null) {
      throw StateError('Flinku SDK not configured. Call Flinku.configure() first.');
    }

    _prefs ??= await SharedPreferences.getInstance();

    if (_prefs!.getBool(_matchedKey) == true) {
      final raw = _prefs!.getString(_matchResultKey);
      if (raw != null) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _hasMatched = true;
          return FlinkuLink.fromJson(map);
        } catch (_) {
          _hasMatched = true;
          return FlinkuLink.notMatched();
        }
      }
      _hasMatched = true;
      return FlinkuLink.notMatched();
    }

    final client = FlinkuHttp(_config!);
    final userAgent = 'Flutter/${Platform.operatingSystem}';
    final response = await client.match(userAgent: userAgent);
    final link = FlinkuLink.fromJson(response);

    if (link.matched) {
      await _prefs!.setBool(_matchedKey, true);
      await _prefs!.setString(_matchResultKey, jsonEncode(response));
      _hasMatched = true;
    }

    return link;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_matchedKey);
    await prefs.remove(_matchResultKey);
    _hasMatched = false;
  }

  static void _log(String message) {
    if (_config?.debug ?? false) {
      // ignore: avoid_print
      print('[Flinku] $message');
    }
  }
}
