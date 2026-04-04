/// Runtime configuration for the Flinku SDK, produced by [Flinku.configure].
///
/// You typically do not construct this directly; use [Flinku.configure] instead.
class FlinkuConfig {
  /// Project subdomain URL, e.g. `https://myapp.flku.dev`.
  final String baseUrl;

  /// When `true`, the SDK prints debug messages to the console.
  final bool debug;

  /// Network timeout for HTTP requests issued by the SDK.
  final Duration timeout;

  /// Creates a configuration value.
  const FlinkuConfig({
    required this.baseUrl,
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
}
