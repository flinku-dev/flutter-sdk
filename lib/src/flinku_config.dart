class FlinkuConfig {
  final String apiKey;
  final String baseUrl;
  final bool debugMode;

  const FlinkuConfig({
    required this.apiKey,
    this.baseUrl = 'http://159.65.159.159:3001',
    this.debugMode = false,
  });
}
