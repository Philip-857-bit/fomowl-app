import 'discover_dapp_entry.dart';

class DiscoverCatalogSnapshot {
  const DiscoverCatalogSnapshot({required this.dapps, required this.fetchedAt});

  final List<DiscoverDappEntry> dapps;
  final DateTime fetchedAt;

  bool get isFresh =>
      DateTime.now().toUtc().difference(fetchedAt) <= const Duration(hours: 1);

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'dapps': dapps.map((entry) => entry.toJson()).toList(growable: false),
  };

  factory DiscoverCatalogSnapshot.fromJson(Map<String, dynamic> json) {
    return DiscoverCatalogSnapshot(
      fetchedAt:
          DateTime.tryParse((json['fetchedAt'] ?? '').toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dapps: (json['dapps'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (entry) =>
                DiscoverDappEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}
