import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
///     apiKey: 'flk_pk_...',
///   );
///   runApp(MyApp());
/// }
/// ```
///
/// Use your publishable key (`flk_pk_`) in apps. Never embed your secret key (`flk_live_`).
class Flinku {
  Flinku._();

  static FlinkuConfig? _config;
  static String? _apiKey;
  static String? _apiBaseUrl;
  static bool _hasMatched = false;
  static bool _secretKeyWarningShown = false;
  static bool _referralApiKeyWarningShown = false;
  static SharedPreferences? _prefs;

  static const String _matchedKey = 'flinku_matched';
  static const String _matchResultKey = 'flinku_match_result';
  static const String _userIdKey = 'flinku_user_id';
  /// Survives [reset]. Used by [qualifyReferral] after the pending record is cleared.
  static const String _referralProjectIdKey = 'flinku_referral_project_id';
  static const String _pendingReferralKeyPrefix = 'flinku_pending_referral_';
  static const String _pendingReferralIndexKey = 'flinku_pending_referral_index';
  static const String _referralTrackedKeyPrefix = 'referral_tracked_';
  static const Duration _pendingReferralTtl = Duration(days: 30);

  static String _referralTrackedKey(String projectId, String userId) =>
      '$_referralTrackedKeyPrefix${projectId}_$userId';

  static String _pendingReferralKey(String projectId) =>
      '$_pendingReferralKeyPrefix$projectId';

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
  /// Accepts publishable keys (`flk_pk_`) or secret keys (`flk_live_`).
  /// Use your publishable key (`flk_pk_`) in apps. Never embed your secret key (`flk_live_`).
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
    if (apiKey != null &&
        apiKey.startsWith('flk_live_') &&
        kDebugMode &&
        !_secretKeyWarningShown) {
      _secretKeyWarningShown = true;
      debugPrint(
        'FLINKU WARNING: You are embedding a secret key (flk_live_) in your app. '
        'Anyone can extract it and gain full access to your links. '
        'Use your publishable key (flk_pk_) instead — find it in your project settings at app.flinku.dev.',
      );
    }
    _log('Flinku SDK configured');
    // Retry a pending referral track if a userId was already stored (e.g. app relaunch).
    unawaited(_retryPendingReferralAfterConfigure());
  }

  static Future<void> _retryPendingReferralAfterConfigure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey)?.trim();
      if (userId == null || userId.isEmpty) return;
      if (!_hasReferralApiKey()) return;
      await _trackPendingReferral(prefs, userId);
    } catch (e) {
      _log('configure referral retry error: $e');
    }
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
  /// Tries fingerprint matching first, then reads the system clipboard for a
  /// Flinku short link (`.flku.dev` or your [baseUrl]) and retries via
  /// clipboard matching when fingerprint returns no match.
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

      final fingerprintResult = await _matchFingerprint();
      if (fingerprintResult != null) {
        return fingerprintResult;
      }

      // Clipboard-based deferred deep linking
      try {
        final clipData = await Clipboard.getData(Clipboard.kTextPlain);
        final clipText = clipData?.text ?? '';
        final baseUrl = _config!.baseUrl;
        if (clipText.isNotEmpty &&
            (clipText.contains('.flku.dev') || clipText.contains(baseUrl))) {
          await Clipboard.setData(const ClipboardData(text: ''));
          final clipResult = await _matchWithUrl(clipText);
          if (clipResult != null) return clipResult;
        }
      } catch (_) {}

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<FlinkuLink?> _matchFingerprint() async {
    return _postMatch(<String, dynamic>{
      'subdomain': _config!.subdomain,
      'userAgent': 'flutter/${Platform.operatingSystem}',
    });
  }

  static Future<FlinkuLink?> _matchWithUrl(String url) async {
    return _postMatch(<String, dynamic>{
      'subdomain': _config!.subdomain,
      'clipboardUrl': url,
    });
  }

  static Future<FlinkuLink?> _postMatch(Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/match');
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
      await _persistPendingReferralIfNeeded(_prefs!, data);
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
      throw FlinkuException(_linkCreationErrorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return FlinkuCreatedLink.fromJson(data);
  }

  /// Creates a short link optimistically: returns [FlinkuCreatedLink] immediately
  /// with a locally generated slug and short URL, then registers the link on
  /// the server in the background.
  ///
  /// Requires [apiKey] to be set in [configure].
  static FlinkuCreatedLink createLinkInstant(FlinkuLinkOptions options) {
    if (_apiKey == null) {
      throw FlinkuException('apiKey is required to create links');
    }
    if (_config == null || _apiBaseUrl == null) {
      throw StateError('Flinku SDK not configured. Call Flinku.configure() first.');
    }

    final slug = _generateInstantSlug(options.title);
    final shortUrl = 'https://${_config!.subdomain}.flku.dev/$slug';
    _createLinkInstantInBackground(options, slug);

    return FlinkuCreatedLink(
      id: '',
      slug: slug,
      shortUrl: shortUrl,
      deepLink: options.deepLink,
      params: options.params,
    );
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
      throw FlinkuException(_linkCreationErrorMessage(response));
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

  /// Clears the cached match result so the next [match] can hit the network again.
  ///
  /// Does **not** clear pending referral attribution or the stored user id.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_matchedKey);
    await prefs.remove(_matchResultKey);
    _hasMatched = false;
  }

  /// Clears all Flinku local state, including referral attribution and stored user id.
  ///
  /// **Testing only — do not call in production.** Clearing attribution destroys
  /// real referral data. [reset] was narrowed in 0.6.0 so production deep-link
  /// handling does not wipe referrals; use [resetAll] only when you need a full
  /// wipe during development or QA.
  static Future<void> resetAll() async {
    await reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_referralProjectIdKey);
    await prefs.remove(_matchResultKey);

    for (final projectId in _getPendingReferralIndex(prefs)) {
      await prefs.remove(_pendingReferralKey(projectId));
    }
    await prefs.remove(_pendingReferralIndexKey);

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_pendingReferralKeyPrefix) ||
          key.startsWith(_referralTrackedKeyPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Stores [userId] locally and tracks a pending referral in the background.
  ///
  /// Returns immediately. Network work never blocks or throws to the caller.
  /// Reads the dedicated pending-referral record written at match time (not the
  /// match cache), so [reset] cannot drop attribution.
  /// Tracks at most once per project+user (`referral_tracked_{projectId}_{userId}`).
  /// Requires [apiKey] in [configure]; otherwise logs a one-time warning and skips.
  static void setUserId(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _warnMissingReferralApiKeyOnce();
    unawaited(_setUserIdInBackground(id));
  }

  /// Marks the stored user as a qualified referral for optional [event].
  ///
  /// No-op if [setUserId] has not been called. Returns immediately.
  /// Requires [apiKey] in [configure]; otherwise logs a one-time warning and skips.
  static void qualifyReferral([String? event]) {
    _warnMissingReferralApiKeyOnce();
    unawaited(_qualifyReferralInBackground(event));
  }

  static bool _hasReferralApiKey() =>
      _apiKey != null && _apiKey!.trim().isNotEmpty;

  static void _warnMissingReferralApiKeyOnce() {
    if (_hasReferralApiKey() || _referralApiKeyWarningShown) return;
    _referralApiKeyWarningShown = true;
    // ignore: avoid_print
    print(
      "[Flinku] Referral tracking skipped: no apiKey configured. Pass apiKey: 'flk_pk_...' to Flinku.configure().",
    );
  }

  /// Writes `flinku_pending_referral_{projectId}` when the match has a referrerId.
  /// Independent of the match cache so it survives [reset].
  static Future<void> _persistPendingReferralIfNeeded(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    final projectId = data['projectId']?.toString().trim() ?? '';
    if (projectId.isEmpty) return;

    final paramsRaw = data['params'];
    if (paramsRaw is! Map) return;
    final params = Map<String, dynamic>.from(paramsRaw);
    final referrerId = params['referrerId']?.toString().trim() ??
        params['referrer_id']?.toString().trim();
    if (referrerId == null || referrerId.isEmpty) return;

    final referrerLabel = params['referrerLabel']?.toString().trim() ??
        params['referrer_label']?.toString().trim();
    final linkId = data['linkId']?.toString().trim() ??
        data['id']?.toString().trim() ??
        data['slug']?.toString().trim();

    final value = <String, dynamic>{
      'referrerId': referrerId,
      'matchedAt': DateTime.now().millisecondsSinceEpoch / 1000.0,
      if (referrerLabel != null && referrerLabel.isNotEmpty)
        'referrerLabel': referrerLabel,
      if (linkId != null && linkId.isNotEmpty) 'linkId': linkId,
    };

    await prefs.setString(_pendingReferralKey(projectId), jsonEncode(value));
    await prefs.setString(_referralProjectIdKey, projectId);
    await _addPendingReferralIndex(prefs, projectId);
  }

  static List<String> _getPendingReferralIndex(SharedPreferences prefs) {
    final raw = prefs.getString(_pendingReferralIndexKey);
    if (raw == null || raw.isEmpty) {
      final pid = prefs.getString(_referralProjectIdKey)?.trim();
      return pid != null && pid.isNotEmpty ? [pid] : [];
    }
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Future<void> _addPendingReferralIndex(
    SharedPreferences prefs,
    String projectId,
  ) async {
    final ids = _getPendingReferralIndex(prefs);
    if (!ids.contains(projectId)) {
      ids.add(projectId);
    }
    await prefs.setString(_pendingReferralIndexKey, ids.join(','));
  }

  static Future<void> _removePendingReferralIndex(
    SharedPreferences prefs,
    String projectId,
  ) async {
    final ids = _getPendingReferralIndex(prefs)..remove(projectId);
    if (ids.isEmpty) {
      await prefs.remove(_pendingReferralIndexKey);
    } else {
      await prefs.setString(_pendingReferralIndexKey, ids.join(','));
    }
  }

  static Future<void> _clearPendingReferral(
    SharedPreferences prefs,
    String projectId,
  ) async {
    await prefs.remove(_pendingReferralKey(projectId));
    await _removePendingReferralIndex(prefs, projectId);
  }

  /// Returns `(projectId, payload)` for a non-expired pending referral, or null.
  static Future<({String projectId, Map<String, dynamic> payload})?>
      _loadPendingReferral(SharedPreferences prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_pendingReferralKeyPrefix)) continue;
      final projectId = key.substring(_pendingReferralKeyPrefix.length);
      if (projectId.isEmpty) continue;

      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      Map<String, dynamic> json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        await prefs.remove(key);
        continue;
      }

      final matchedAtRaw = json['matchedAt'];
      final matchedAt = matchedAtRaw is num
          ? matchedAtRaw.toDouble()
          : double.tryParse(matchedAtRaw?.toString() ?? '');
      if (matchedAt == null) {
        await prefs.remove(key);
        continue;
      }
      if (now - matchedAt > _pendingReferralTtl.inSeconds) {
        await prefs.remove(key);
        await _removePendingReferralIndex(prefs, projectId);
        continue;
      }

      final referrerId = json['referrerId']?.toString().trim() ?? '';
      if (referrerId.isEmpty) {
        await prefs.remove(key);
        continue;
      }

      return (projectId: projectId, payload: json);
    }
    return null;
  }

  static Future<void> _setUserIdInBackground(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      if (!_hasReferralApiKey()) return;
      await _trackPendingReferral(prefs, userId);
    } catch (e) {
      _log('setUserId background error: $e');
    }
  }

  static Future<void> _trackPendingReferral(
    SharedPreferences prefs,
    String userId,
  ) async {
    final pending = await _loadPendingReferral(prefs);
    if (pending == null) return;

    final projectId = pending.projectId;
    final json = pending.payload;
    final trackedKey = _referralTrackedKey(projectId, userId);
    if (prefs.getBool(trackedKey) == true) {
      await _clearPendingReferral(prefs, projectId);
      return;
    }

    final referrerId = json['referrerId']?.toString().trim() ?? '';
    if (referrerId.isEmpty) {
      await _clearPendingReferral(prefs, projectId);
      return;
    }

    final referrerLabel = json['referrerLabel']?.toString().trim();
    final linkId = json['linkId']?.toString().trim();

    final body = <String, dynamic>{
      'projectId': projectId,
      'referrerId': referrerId,
      'newUserId': userId,
      if (referrerLabel != null && referrerLabel.isNotEmpty)
        'referrerLabel': referrerLabel,
      if (linkId != null && linkId.isNotEmpty) 'linkId': linkId,
    };

    await prefs.setString(_referralProjectIdKey, projectId);

    final ok = await _postReferral('/api/referrals/track', body);
    if (!ok) return;
    await prefs.setBool(trackedKey, true);
    await _clearPendingReferral(prefs, projectId);
  }

  static Future<void> _qualifyReferralInBackground(String? event) async {
    try {
      if (!_hasReferralApiKey()) return;
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey)?.trim();
      if (userId == null || userId.isEmpty) return;

      var projectId = prefs.getString(_referralProjectIdKey)?.trim() ?? '';
      if (projectId.isEmpty) {
        final pending = await _loadPendingReferral(prefs);
        projectId = pending?.projectId ?? '';
      }
      if (projectId.isEmpty) {
        final raw = prefs.getString(_matchResultKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            projectId = data['projectId']?.toString().trim() ?? '';
          } catch (_) {}
        }
      }
      if (projectId.isEmpty) return;

      final body = <String, dynamic>{
        'projectId': projectId,
        'newUserId': userId,
        if (event != null && event.trim().isNotEmpty) 'event': event.trim(),
      };
      await _postReferral('/api/referrals/qualify', body);
    } catch (e) {
      _log('qualifyReferral background error: $e');
    }
  }

  /// Returns true on HTTP 2xx. On failure the caller keeps the pending record.
  static Future<bool> _postReferral(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (_apiBaseUrl == null || !_hasReferralApiKey()) {
      _log('referral skipped: not configured');
      return false;
    }
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };
      final response = await http.post(
        Uri.parse('$_apiBaseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log('referral $path error: HTTP ${response.statusCode}');
        return false;
      }
      return true;
    } catch (e) {
      _log('referral $path error: $e');
      return false;
    }
  }

  static void _log(String message) {
    if (_config?.debug ?? false) {
      // ignore: avoid_print
      print('[Flinku] $message');
    }
  }

  static String _linkCreationErrorMessage(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return 'Failed to create link: HTTP ${response.statusCode}';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return body;
  }

  static String _generateInstantSlug(String title) {
    var base = title.toLowerCase().trim();
    base = base.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    base = base.replaceAll(RegExp(r'\s+'), '-');
    base = base.replaceAll(RegExp(r'-+'), '-');
    base = base.replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) {
      base = 'link';
    }
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    final suffix = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return '$base-$suffix';
  }

  static void _createLinkInstantInBackground(
    FlinkuLinkOptions options,
    String slug,
  ) {
    final body = Map<String, dynamic>.from(options.toJson())..['slug'] = slug;
    final uri = Uri.parse('$_apiBaseUrl/api/links');
    unawaited(() async {
      try {
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          final message = _linkCreationErrorMessage(response);
          _log('createLinkInstant background error: $message');
        }
      } catch (e) {
        _log('createLinkInstant background error: $e');
      }
    }());
  }
}
