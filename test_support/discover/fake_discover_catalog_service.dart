import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_service.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';

class FakeDiscoverCatalogService extends DiscoverCatalogService {
  FakeDiscoverCatalogService({
    required this.snapshot,
    this.cachedSnapshot,
    this.error,
  });

  final DiscoverCatalogSnapshot snapshot;
  final DiscoverCatalogSnapshot? cachedSnapshot;
  final Object? error;

  @override
  Future<DiscoverCatalogSnapshot?> loadCachedSnapshot() async => cachedSnapshot;

  @override
  Future<DiscoverCatalogSnapshot> getSnapshot({
    bool forceRefresh = false,
  }) async {
    if (error != null) {
      throw error!;
    }
    return snapshot;
  }
}
