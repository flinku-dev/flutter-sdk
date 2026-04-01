import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'flinku_config.dart';
import 'flinku_link.dart';

class FlinkuLinkOptions {
  final String title;
  final String? deepLink;
  final Map<String, String>? params;
  final String? slug;
  final String? desktopUrl;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;
  final String? utmTerm;
  final DateTime? expiresAt;
  final int? maxClicks;
  final String? password;
  final String? ogTitle;
  final String? ogDescription;
  final String? ogImageUrl;

  const FlinkuLinkOptions({
    required this.title,
    this.deepLink,
    this.params,
    this.slug,
    this.desktopUrl,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
    this.utmTerm,
    this.expiresAt,
    this.maxClicks,
    this.password,
    this.ogTitle,
    this.ogDescription,
    this.ogImageUrl,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (deepLink != null) 'deepLink': deepLink,
        if (params != null) 'params': params,
        if (slug != null) 'slug': slug,
        if (desktopUrl != null) 'desktopUrl': desktopUrl,
        if (utmSource != null) 'utmSource': utmSource,
        if (utmMedium != null) 'utmMedium': utmMedium,
        if (utmCampaign != null) 'utmCampaign': utmCampaign,
        if (utmContent != null) 'utmContent': utmContent,
        if (utmTerm != null) 'utmTerm': utmTerm,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (maxClicks != null) 'maxClicks': maxClicks,
        if (password != null) 'password': password,
        if (ogTitle != null) 'ogTitle': ogTitle,
        if (ogDescription != null) 'ogDescription': ogDescription,
        if (ogImageUrl != null) 'ogImageUrl': ogImageUrl,
      };
}

class FlinkuCreatedLink {
  final String id;
  final String slug;
  final String shortUrl;
  final String? deepLink;
  final Map<String, String>? params;

  const FlinkuCreatedLink({
    required this.id,
    required this.slug,
    required this.shortUrl,
    this.deepLink,
    this.params,
  });

  factory FlinkuCreatedLink.fromJson(Map<String, dynamic> json) {
    Map<String, String>? params;
    final raw = json['params'];
    if (raw is Map) {
      params = raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return FlinkuCreatedLink(
      id: json['id'] as String,
      slug: json['slug'] as String,
      shortUrl: json['shortUrl'] as String,
      deepLink: json['deepLink'] as String?,
      params: params,
    );
  }
}

class FlinkuException implements Exception {
  FlinkuException(this.message);
  final String message;

  @override
  String toString() => message;
}

class Flinku {
  Flinku._();

  static FlinkuConfig? _config;
  static String? _apiKey;
  static String? _apiBaseUrl;
  static bool _hasMatched = false;
  static SharedPreferences? _prefs;

  static const String _matchedKey = 'flinku_matched';
  static const String _matchResultKey = 'flinku_match_result';

  /// Root API origin derived from [baseUrl]: strip the first host label (subdomain).
  /// e.g. `https://masroofati.flku.dev` → `https://flku.dev`
  static String _deriveApiBaseUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'https';
    if (uri.host.isEmpty) {
      return baseUrl;
    }
    final parts = uri.host.split('.');
    final host = parts.length >= 3 ? parts.sublist(1).join('.') : uri.host;
    final int? port;
    if (scheme == 'https' && uri.port != 443) {
      port = uri.port;
    } else if (scheme == 'http' && uri.port != 80) {
      port = uri.port;
    } else if (scheme != 'https' && scheme != 'http') {
      port = uri.port;
    } else {
      port = null;
    }
    return Uri(scheme: scheme, host: host, port: port).origin;
  }

  /// Configure Flinku with your project subdomain URL.
  ///
  /// Optional [apiKey] is required for [createLink] / [createLinks].
  ///
  /// Call this once in main() before runApp():
  /// ```dart
  /// Flinku.configure(baseUrl: 'https://yourapp.flku.dev');
  /// ```
  static void configure({
    required String baseUrl,
    String? apiKey,
    bool debug = false,
    Duration timeout = const Duration(seconds: 5),
  }) {
    _config = FlinkuConfig(
      baseUrl: baseUrl,
      debug: debug,
      timeout: timeout,
    );
    _apiKey = apiKey;
    _apiBaseUrl = _deriveApiBaseUrl(baseUrl);
    _log('Flinku SDK configured');
  }

  /// Returns true if Flinku.match() has already been called
  /// and a match was found. Prevents double-matching.
  static bool get hasMatched => _hasMatched;

  /// Calls `POST $apiBaseUrl/api/match` with [subdomain] and user agent from [baseUrl].
  ///
  /// Returns a [FlinkuLink] when the API sets `matched: true`; otherwise `null`.
  /// Returns `null` on any error or non-200 response.
  static Future<FlinkuLink?> match() async {
    if (_config == null || _apiBaseUrl == null) {
      throw StateError('Flinku SDK not configured. Call Flinku.configure() first.');
    }

    try {
      _prefs ??= await SharedPreferences.getInstance();

      if (_prefs!.getBool(_matchedKey) == true) {
        final raw = _prefs!.getString(_matchResultKey);
        if (raw != null) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            if (map['matched'] == true) {
              final link = FlinkuLink.fromJson(map);
              _hasMatched = true;
              return link;
            }
          } catch (_) {
            return null;
          }
        }
        return null;
      }

      final uri = Uri.parse('$_apiBaseUrl/api/match');
      final body = <String, dynamic>{
        'subdomain': _config!.subdomain,
        'userAgent': 'flutter/${Platform.operatingSystem}',
      };

      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_config!.timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }

      if (data['matched'] != true) {
        return null;
      }

      final link = FlinkuLink.fromJson(data);
      await _prefs!.setBool(_matchedKey, true);
      await _prefs!.setString(_matchResultKey, jsonEncode(data));
      _hasMatched = true;
      return link;
    } catch (_) {
      return null;
    }
  }

  /// Creates a new deep link using your project API key.
  ///
  /// Set [apiKey] in [configure].
  static Future<FlinkuCreatedLink> createLink(FlinkuLinkOptions options) async {
    if (_apiKey == null) {
      throw FlinkuException('apiKey is required to create links');
    }
    if (_config == null || _apiBaseUrl == null) {
      throw StateError('Flinku SDK not configured. Call Flinku.configure() first.');
    }

    final uri = Uri.parse('$_apiBaseUrl/api/links');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(options.toJson()),
        )
        .timeout(_config!.timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw FlinkuException('Failed to create link: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return FlinkuCreatedLink.fromJson(data);
  }

  /// Creates multiple links in bulk using your project API key.
  ///
  /// Set [apiKey] in [configure].
  static Future<List<FlinkuCreatedLink>> createLinks(
    List<FlinkuLinkOptions> links,
  ) async {
    if (_apiKey == null) {
      throw FlinkuException('apiKey is required to create links');
    }
    if (_config == null || _apiBaseUrl == null) {
      throw StateError('Flinku SDK not configured. Call Flinku.configure() first.');
    }

    final uri = Uri.parse('$_apiBaseUrl/api/links/bulk');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'links': links.map((l) => l.toJson()).toList(),
          }),
        )
        .timeout(_config!.timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw FlinkuException('Failed to create links: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['links'] as List<dynamic>?;
    if (list == null) {
      throw FlinkuException('Invalid bulk create response: missing links');
    }
    return list
        .map((l) => FlinkuCreatedLink.fromJson(l as Map<String, dynamic>))
        .toList();
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
