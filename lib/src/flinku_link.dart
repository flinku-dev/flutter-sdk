class FlinkuLink {
  final bool matched;
  final String? deepLink;
  final String? slug;
  final String? subdomain;
  final String? title;
  final Map<String, dynamic>? params;
  final DateTime? clickedAt;
  final String? projectId;

  const FlinkuLink({
    required this.matched,
    this.deepLink,
    this.slug,
    this.subdomain,
    this.title,
    this.params,
    this.clickedAt,
    this.projectId,
  });

  factory FlinkuLink.fromJson(Map<String, dynamic> json) {
    return FlinkuLink(
      matched: json['matched'] == true,
      deepLink: json['deepLink'] as String?,
      slug: json['slug'] as String?,
      subdomain: json['subdomain'] as String?,
      title: json['title'] as String?,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
      clickedAt: json['clickedAt'] != null
          ? DateTime.tryParse(json['clickedAt'] as String)
          : null,
      projectId: json['projectId'] as String?,
    );
  }

  factory FlinkuLink.notMatched() {
    return const FlinkuLink(matched: false);
  }

  @override
  String toString() {
    return 'FlinkuLink(matched: $matched, deepLink: $deepLink, '
        'subdomain: $subdomain, params: $params, title: $title)';
  }
}
