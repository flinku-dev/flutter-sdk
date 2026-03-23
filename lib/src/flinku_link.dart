class FlinkuLink {
  final bool matched;
  final String? deepLink;
  final Map<String, dynamic>? params;
  final String? slug;

  const FlinkuLink({
    required this.matched,
    this.deepLink,
    this.params,
    this.slug,
  });

  factory FlinkuLink.fromJson(Map<String, dynamic> json) {
    return FlinkuLink(
      matched: json['matched'] ?? false,
      deepLink: json['deepLink'],
      params: json['params'] is Map<String, dynamic>
          ? json['params'] as Map<String, dynamic>
          : null,
      slug: json['slug'],
    );
  }

  factory FlinkuLink.noMatch() {
    return const FlinkuLink(matched: false);
  }
}
