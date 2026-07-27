typedef SwapClock = DateTime Function();

/// Shared, TTL-bound token price repository used by swap presentation logic.
class SwapPriceCache {
  SwapPriceCache({this.ttl = const Duration(minutes: 2), SwapClock? clock})
    : _clock = clock ?? DateTime.now;

  static final SwapPriceCache shared = SwapPriceCache();

  final Duration ttl;
  final SwapClock _clock;
  final Map<String, double> _prices = {};
  final Map<String, DateTime> _updatedAt = {};

  double? read(String? key) {
    if (key == null || key.isEmpty) return null;
    final price = _prices[key];
    final updatedAt = _updatedAt[key];
    if (price == null || updatedAt == null) return null;
    if (_clock().difference(updatedAt) > ttl) {
      _prices.remove(key);
      _updatedAt.remove(key);
      return null;
    }
    return price;
  }

  void putAll(Map<String, double> prices) {
    if (prices.isEmpty) return;
    final now = _clock();
    for (final entry in prices.entries) {
      _prices[entry.key] = entry.value;
      _updatedAt[entry.key] = now;
    }
  }

  void clear() {
    _prices.clear();
    _updatedAt.clear();
  }
}
