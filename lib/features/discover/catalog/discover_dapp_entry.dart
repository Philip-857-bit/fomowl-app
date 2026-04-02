class DiscoverDappEntry {
  const DiscoverDappEntry({
    required this.id,
    required this.slug,
    required this.origin,
    required this.launchUrl,
    required this.title,
    required this.subtitle,
    required this.logoUrl,
    required this.heroImageUrl,
    required this.badgeText,
    required this.categories,
    required this.supportedChainIds,
    required this.featuredRank,
    required this.trendingRank,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String slug;
  final String origin;
  final String launchUrl;
  final String title;
  final String? subtitle;
  final String? logoUrl;
  final String? heroImageUrl;
  final String? badgeText;
  final List<String> categories;
  final List<int> supportedChainIds;
  final int? featuredRank;
  final int? trendingRank;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  factory DiscoverDappEntry.fromJson(Map<String, dynamic> json) {
    String requireTextField(String key) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw FormatException('Discover DApp is missing required field: $key');
      }
      return value;
    }

    return DiscoverDappEntry(
      id: requireTextField('id'),
      slug: requireTextField('slug'),
      origin: requireTextField('origin'),
      launchUrl: requireTextField('launchUrl'),
      title: requireTextField('title'),
      subtitle: json['subtitle']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      heroImageUrl: json['heroImageUrl']?.toString(),
      badgeText: json['badgeText']?.toString(),
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      supportedChainIds:
          (json['supportedChainIds'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (value) => switch (value) {
                  int intValue => intValue,
                  String stringValue => int.tryParse(stringValue) ?? 0,
                  _ => 0,
                },
              )
              .where((value) => value > 0)
              .toList(growable: false),
      featuredRank: _asInt(json['featuredRank']),
      trendingRank: _asInt(json['trendingRank']),
      isActive: json['isActive'] != false,
      createdAt: requireTextField('createdAt'),
      updatedAt: requireTextField('updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'origin': origin,
    'launchUrl': launchUrl,
    'title': title,
    'subtitle': subtitle,
    'logoUrl': logoUrl,
    'heroImageUrl': heroImageUrl,
    'badgeText': badgeText,
    'categories': categories,
    'supportedChainIds': supportedChainIds,
    'featuredRank': featuredRank,
    'trendingRank': trendingRank,
    'isActive': isActive,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(normalized) ||
        slug.toLowerCase().contains(normalized) ||
        origin.toLowerCase().contains(normalized) ||
        launchUrl.toLowerCase().contains(normalized) ||
        categories.any(
          (category) => category.toLowerCase().contains(normalized),
        ) ||
        (subtitle?.toLowerCase().contains(normalized) ?? false);
  }

  static int? _asInt(Object? value) {
    return switch (value) {
      int intValue => intValue,
      String stringValue => int.tryParse(stringValue),
      _ => null,
    };
  }
}
