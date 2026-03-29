class BrowserHistoryEntry {
  const BrowserHistoryEntry({
    required this.url,
    required this.origin,
    required this.title,
    required this.visitedAt,
  });

  final String url;
  final String origin;
  final String? title;
  final DateTime visitedAt;
}
