class FlinkuConfig {
  final String baseUrl;
  final bool debug;
  final Duration timeout;

  const FlinkuConfig({
    required this.baseUrl,
    this.debug = false,
    this.timeout = const Duration(seconds: 5),
  });

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
