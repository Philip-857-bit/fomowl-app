class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.description,
    required this.linkUrl,
    required this.sortOrder,
    this.imageUrl,
    this.ctaLabel,
  });

  final String id;
  final String title;
  final String description;
  final String linkUrl;
  final String? imageUrl;
  final String? ctaLabel;
  final int sortOrder;

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) {
    return HomeBannerItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Featured update').toString(),
      description: (json['description'] ?? '').toString(),
      linkUrl: (json['linkUrl'] ?? '').toString(),
      imageUrl: _optionalString(json['imageUrl']),
      ctaLabel: _optionalString(json['ctaLabel']),
      sortOrder: _asInt(json['sortOrder']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'linkUrl': linkUrl,
    'imageUrl': imageUrl,
    'ctaLabel': ctaLabel,
    'sortOrder': sortOrder,
  };

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class HomeBannerFeed {
  const HomeBannerFeed({
    required this.banners,
    required this.showFallbackSocialBanner,
  });

  final List<HomeBannerItem> banners;
  final bool showFallbackSocialBanner;

  Map<String, dynamic> toJson() => {
    'banners': banners.map((item) => item.toJson()).toList(growable: false),
    'showFallbackSocialBanner': showFallbackSocialBanner,
  };

  factory HomeBannerFeed.fromJson(Map<String, dynamic> json) {
    final items = json['banners'];
    return HomeBannerFeed(
      banners: items is List
          ? items
                .whereType<Map>()
                .map(
                  (item) =>
                      HomeBannerItem.fromJson(item.cast<String, dynamic>()),
                )
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const <HomeBannerItem>[],
      showFallbackSocialBanner: json['showFallbackSocialBanner'] != false,
    );
  }
}
