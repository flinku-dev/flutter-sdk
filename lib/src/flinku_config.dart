/// Thrown when [baseUrl] passed to [Flinku.configure] is invalid.
const invalidBaseUrlMessage =
    'Invalid baseUrl: expected https://{subdomain}.flku.dev (e.g. https://myapp.flku.dev)';

/// Root API origin for Flinku HTTP calls (match, links, referrals).
const flinkuApiBaseUrl = 'https://flku.dev';

/// Parses and validates a project [baseUrl] from [Flinku.configure].
///
/// Accepts `https://{subdomain}.flku.dev` with an optional trailing slash.
({String baseUrl, String subdomain}) parseProjectBaseUrl(String baseUrl) {
  final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final match = RegExp(r'^https://([^.]+)\.flku\.dev$', caseSensitive: false)
      .firstMatch(trimmed);
  if (match == null) {
    throw ArgumentError(invalidBaseUrlMessage);
  }
  return (baseUrl: trimmed, subdomain: match.group(1)!);
}

/// Normalizes optional [customDomain] from [Flinku.configure] (host only).
String? normalizeCustomDomain(String? customDomain) {
  if (customDomain == null) return null;
  final trimmed = customDomain.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'\s').hasMatch(trimmed)) {
    throw ArgumentError('Invalid customDomain: must be a host name without whitespace');
  }
  if (trimmed.contains('://') || trimmed.contains('/') || trimmed.contains(':')) {
    throw ArgumentError('Invalid customDomain: must be a host name only');
  }
  var host = trimmed.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.isEmpty) return null;
  return host;
}

/// Host from clipboard text when it looks like a URL, else null.
String? hostFromClipboardText(String clipText) {
  final trimmed = clipText.trim();
  if (trimmed.isEmpty) return null;
  final withScheme =
      trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.host.toLowerCase();
  }
  final urlMatch =
      RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(trimmed);
  if (urlMatch != null) {
    final u = Uri.tryParse(urlMatch.group(0)!);
    if (u != null && u.host.isNotEmpty) {
      return u.host.toLowerCase();
    }
  }
  return null;
}

/// Whether clipboard [clipText] should be sent to `/api/match` as [clipboardUrl].
bool flinkuClipboardUrlAccepted(String clipText, FlinkuConfig config) {
  final host = hostFromClipboardText(clipText);
  if (host == null) return false;
  if (host.endsWith('.flku.dev')) return true;
  final baseHost = Uri.parse(config.baseUrl).host.toLowerCase();
  if (host == baseHost) return true;
  final custom = config.customDomain?.toLowerCase();
  if (custom != null && host == custom) return true;
  return false;
}

/// Runtime configuration for the Flinku SDK, produced by [Flinku.configure].
///
/// You typically do not construct this directly; use [Flinku.configure] instead.
class FlinkuConfig {
  /// Project subdomain URL, e.g. `https://myapp.flku.dev`.
  final String baseUrl;

  /// Active custom link domain host (no scheme), when set in [Flinku.configure].
  final String? customDomain;

  /// When `true`, the SDK prints debug messages to the console.
  final bool debug;

  /// Network timeout for HTTP requests issued by the SDK.
  final Duration timeout;

  /// Creates a configuration value.
  const FlinkuConfig({
    required this.baseUrl,
    this.customDomain,
    this.debug = false,
    this.timeout = const Duration(seconds: 5),
  });

  /// First DNS label of [baseUrl]'s host when there are at least three labels;
  /// otherwise the full host (e.g. `https://masroofati.flku.dev` → `masroofati`).
  String get subdomain {
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host;
      final parts = host.split('.');
      if (parts.length >= 3) return parts.first;
      return host;
    } catch (_) {
      return '';
    }
  }

  /// Host used for optimistic short URLs from [Flinku.createLinkInstant].
  String get instantLinkHost =>
      customDomain ?? '${subdomain}.flku.dev';
}
