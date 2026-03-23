import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'flinku_config.dart';
import 'flinku_http.dart';
import 'flinku_link.dart';

class Flinku {
  Flinku._();

  static FlinkuConfig? _config;
  static bool _initialized = false;
  static SharedPreferences? _prefs;

  static const String _matchedKey = 'flinku_matched';
  static const String _launchedKey = 'flinku_first_launch_done';

  // Initialize the SDK — call this in main() before runApp()
  static Future<void> configure(FlinkuConfig config) async {
    _config = config;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    _log('Flinku SDK configured');
  }

  // Match deferred deep link — call this once on app first launch
  // Returns FlinkuLink with matched=true if a deferred link is found
  static Future<FlinkuLink> match() async {
    if (!_initialized || _config == null || _prefs == null) {
      throw StateError('Flinku SDK not initialized. Call Flinku.configure() first.');
    }

    try {
      final alreadyMatched = _prefs!.getBool(_matchedKey) ?? false;
      if (alreadyMatched) {
        _log('Match skipped: already matched previously.');
        return FlinkuLink.noMatch();
      }

      final firstLaunch = await _isFirstLaunch();
      if (!firstLaunch) {
        _log('Match skipped: not first launch.');
        return FlinkuLink.noMatch();
      }

      final client = FlinkuHttp(_config!.baseUrl);
      final payload = <String, dynamic>{
        'apiKey': _config!.apiKey,
        'deviceInfo': {
          'platform': Platform.operatingSystem,
          'userAgent': 'Flutter/${Platform.operatingSystemVersion}',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      };

      final response = await client.post('/api/match', payload);
      final link = FlinkuLink.fromJson(response);

      if (link.matched) {
        await _prefs!.setBool(_matchedKey, true);
      }

      await _markLaunched();
      return link;
    } catch (error) {
      _log('Match failed: $error');
      try {
        await _markLaunched();
      } catch (_) {
        // keep failures silent
      }
      return FlinkuLink.noMatch();
    }
  }

  // Check if this is the first launch
  static Future<bool> _isFirstLaunch() async {
    final launched = _prefs?.getBool(_launchedKey) ?? false;
    return !launched;
  }

  // Mark first launch as done
  static Future<void> _markLaunched() async {
    await _prefs?.setBool(_launchedKey, true);
  }

  // Log debug messages if debugMode is true
  static void _log(String message) {
    if (_config?.debugMode ?? false) {
      // ignore: avoid_print
      print('[Flinku] $message');
    }
  }
}
