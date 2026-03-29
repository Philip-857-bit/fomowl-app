class BlockedNavigationState {
  const BlockedNavigationState({
    required this.url,
    required this.origin,
    required this.reason,
  });

  final String url;
  final String origin;
  final String reason;
}
