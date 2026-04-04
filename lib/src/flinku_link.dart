/// Result of a deferred deep link [Flinku.match] call when the server reports a match.
///
/// When [matched] is `false`, use [FlinkuLink.notMatched] for a sentinel value.
class FlinkuLink {
  /// Whether the Flinku API reported a successful deferred match.
  final bool matched;

  /// In-app route or URI to open when the user opened a Flinku short link before install.
  final String? deepLink;

  /// Short link slug segment from the Flinku service, if provided.
  final String? slug;

  /// Project subdomain label associated with the click, if provided.
  final String? subdomain;

  /// Human-readable title from the link metadata, if provided.
  final String? title;

  /// Custom key/value parameters attached to the link in the Flinku dashboard.
  final Map<String, dynamic>? params;

  /// Server-reported click time, if provided as an ISO-8601 string in JSON.
  final DateTime? clickedAt;

  /// Flinku project identifier for the matched link, if provided.
  final String? projectId;

  /// Creates a link result with explicit field values.
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

  /// Parses a JSON object from the Flinku `/api/match` response into a [FlinkuLink].
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

  /// A link result with [matched] set to `false`.
  factory FlinkuLink.notMatched() {
    return const FlinkuLink(matched: false);
  }

  @override
  String toString() {
    return 'FlinkuLink(matched: $matched, deepLink: $deepLink, '
        'subdomain: $subdomain, params: $params, title: $title)';
  }
}
