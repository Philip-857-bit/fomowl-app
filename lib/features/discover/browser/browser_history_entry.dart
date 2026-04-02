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
}
