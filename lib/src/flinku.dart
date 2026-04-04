import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'flinku_config.dart';
import 'flinku_link.dart';

/// Options for [Flinku.createLink] and [Flinku.createLinks].
///
/// Only [title] is required; other fields are sent when non-null.
class FlinkuLinkOptions {
  /// Display title for the link in the Flinku dashboard and metadata.
  final String title;

  /// Target in-app deep link URI, e.g. `myapp://promo`.
  final String? deepLink;

  /// String key/value query-style parameters stored on the link.
  final Map<String, String>? params;

  /// Optional custom slug; if omitted, Flinku may assign one.
  final String? slug;

  /// Fallback URL for desktop or unsupported clients.
  final String? desktopUrl;

  /// UTM `source` parameter for analytics.
  final String? utmSource;

  /// UTM `medium` parameter for analytics.
  final String? utmMedium;

  /// UTM `campaign` parameter for analytics.
  final String? utmCampaign;

  /// UTM `content` parameter for analytics.
  final String? utmContent;

  /// UTM `term` parameter for analytics.
  final String? utmTerm;

  /// Optional expiry time for the link (ISO-8601 in JSON).
  final DateTime? expiresAt;

  /// Maximum allowed clicks before the link stops resolving, if supported.
  final int? maxClicks;

  /// Optional password gate for opening the link.
  final String? password;

  /// Open Graph title for link previews.
  final String? ogTitle;

  /// Open Graph description for link previews.
  final String? ogDescription;

  /// Open Graph image URL for link previews.
  final String? ogImageUrl;

  /// Creates link-creation options for the Flinku Links API.
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

  /// JSON body for `POST /api/links` (and bulk entries).
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

/// A short link returned by [Flinku.createLink] or [Flinku.createLinks].
class FlinkuCreatedLink {
  /// Server-assigned link identifier.
  final String id;

  /// Path segment or slug for the short URL.
  final String slug;

  /// Public HTTPS short URL users can open or share.
  final String shortUrl;

  /// In-app deep link associated with this short link, if any.
  final String? deepLink;

  /// Custom parameters attached to this link, if any.
  final Map<String, String>? params;

  /// Creates a value from an API JSON object.
  const FlinkuCreatedLink({
    required this.id,
    required this.slug,
    required this.shortUrl,
    this.deepLink,
    this.params,
  });

  /// Parses the Flinku Links API JSON response into a [FlinkuCreatedLink].
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

/// Error thrown when link creation fails or [apiKey] is missing.
class FlinkuException implements Exception {
  /// Human-readable explanation of the failure.
  final String message;

  /// Creates an exception with [message].
  FlinkuException(this.message);

  @override
  String toString() => message;
}

/// The main Flinku SDK class for deep linking.
///
/// Configure once at app startup using [Flinku.configure], then call
/// [Flinku.match] on every app launch to retrieve deferred deep links.
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   Flinku.configure(
///     baseUrl: 'https://myapp.flku.dev',
///     apiKey: 'flk_live_...',
///   );
///   runApp(MyApp());
/// }
/// ```
class Flinku {
  Flinku._();

  static FlinkuConfig? _config;
  static String? _apiKey;
  static String? _apiBaseUrl;
  static bool _hasMatched = false;
  static SharedPreferences? _prefs;

  static const String _matchedKey = 'flinku_matched';
  static const String _matchResultKey = 'flinku_match_result';

  // Root API origin: strip first host label from project [baseUrl].
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

  /// Configures the Flinku SDK with your project settings.
  ///
  /// Must be called before other Flinku methods, typically in `main`.
  ///
  /// [baseUrl] is your project subdomain URL, e.g. `https://myapp.flku.dev`.
  /// [apiKey] is optional and required only for [createLink] and [createLinks].
  /// [debug] enables console logging from the SDK.
  /// [timeout] applies to HTTP requests such as [match] and link creation.
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

  /// Whether [match] has already returned a successful [FlinkuLink] this process
  /// or restored one from local storage after a prior successful match.
  ///
  /// Cleared when [reset] runs.
  static bool get hasMatched => _hasMatched;

  /// Matches a deferred deep link for the current install.
  ///
  /// Call on every app launch, for example from your root widget's
  /// [State.initState] or splash flow.
  ///
  /// Returns a [FlinkuLink] if the API responds with `matched: true`, or `null`
  /// if there is no match, a non-200 response, or a network/parse error.
  ///
  /// After a successful match, the JSON payload is stored locally; later calls
  /// return the same [FlinkuLink] without calling the network again until
  /// [reset] clears storage.
  ///
  /// Example:
  /// ```dart
  /// final link = await Flinku.match();
  /// if (link != null) {
  ///   navigateTo(link.deepLink!, params: link.params);
  /// }
  /// ```
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

  /// Creates a new short link programmatically.
  ///
  /// Requires [apiKey] to be set in [configure].
  ///
  /// Example:
  /// ```dart
  /// final link = await Flinku.createLink(FlinkuLinkOptions(
  ///   title: 'Summer Sale',
  ///   deepLink: 'myapp://promo',
  ///   params: {'promo': 'SAVE20'},
  /// ));
  /// print(link.shortUrl);
  /// ```
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

  /// Creates multiple links in bulk.
  ///
  /// Requires [apiKey] to be set in [configure].
  ///
  /// Sends `POST /api/links/bulk` with a `links` array of option maps.
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

  /// Resets the cached match result.
  ///
  /// Clears local storage used by [match] so the next call can hit the network
  /// again. Useful in tests and development.
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
