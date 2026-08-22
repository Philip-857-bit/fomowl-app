class BrowserHistoryEntry {
  const BrowserHistoryEntry({
    required this.url,
    required this.origin,
    this.title,
    required this.visitedAt,
  });

  final String url;
  final String origin;
  final String? title;
  final DateTime visitedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'origin': origin,
    'title': title,
    'visitedAt': visitedAt.toUtc().toIso8601String(),
  };

  factory BrowserHistoryEntry.fromJson(Map<String, dynamic> json) {
    final visitedAtRaw = json['visitedAt']?.toString() ?? '';
    return BrowserHistoryEntry(
      url: json['url']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      title: json['title']?.toString(),
      visitedAt: DateTime.tryParse(visitedAtRaw) ?? DateTime.now(),
    );
  }
}
