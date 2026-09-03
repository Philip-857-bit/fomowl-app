import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/browser/discover_tab_manager.dart';
import 'package:fomowl_wallet/features/discover/browser/discover_tab_storage.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_service.dart';
import 'package:fomowl_wallet/features/discover/catalog/discover_catalog_snapshot.dart';
import 'package:fomowl_wallet/features/discover/permissions/dapp_permission_service.dart';
import 'package:fomowl_wallet/services/secure_store.dart';

class _FakeCatalogService extends DiscoverCatalogService {
  @override
  Future<DiscoverCatalogSnapshot> getSnapshot({
    bool forceRefresh = false,
  }) async => DiscoverCatalogSnapshot(
    dapps: const [],
    fetchedAt: DateTime.utc(2026, 1, 1),
  );
}

class _MemorySecureStore implements SecureStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

Future<DiscoverTabManager> _manager(_MemorySecureStore secureStore) async {
  final manager = DiscoverTabManager(
    catalogService: _FakeCatalogService(),
    permissionService: DappPermissionService(),
    storage: DiscoverTabStorage(secureStore: secureStore),
  );
  await manager.initialize(scopeKey: '0xabc');
  return manager;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {});

  test('enforces five live tabs and selects each new tab', () async {
    final manager = await _manager(_MemorySecureStore());
    addTearDown(manager.dispose);

    for (var index = 0; index < 4; index++) {
      final added = await manager.addTab();
      expect(added, isNotNull);
      expect(manager.activeTabId, added!.id);
    }

    expect(manager.tabCount, 5);
    expect(manager.canAddTab, isFalse);
    expect(await manager.addTab(), isNull);
  });

  test('closing the active tab selects the nearest remaining tab', () async {
    final manager = await _manager(_MemorySecureStore());
    addTearDown(manager.dispose);
    final second = await manager.addTab();
    final third = await manager.addTab();
    expect(manager.activeTabId, third!.id);

    manager.closeTab(third.id);

    expect(manager.tabCount, 2);
    expect(manager.activeTabId, second!.id);
  });

  test('restores URLs, titles, and the active tab', () async {
    final secureStore = _MemorySecureStore();
    final first = await _manager(secureStore);
    first.activeTab.sessionController.restoreBrowsing(
      'https://example.com/tasks',
      title: 'Tasks',
    );
    final secondTab = await first.addTab();
    secondTab!.sessionController.restoreBrowsing(
      'https://example.org/airdrop',
      title: 'Airdrop',
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    first.dispose();

    final restored = await _manager(secureStore);
    addTearDown(restored.dispose);

    expect(restored.tabCount, 2);
    expect(
      restored.activeTab.sessionController.currentUri.toString(),
      'https://example.org/airdrop',
    );
    expect(restored.activeTab.sessionController.pageTitle, 'Airdrop');
  });

  test('storage drops malformed tabs and caps restored data', () async {
    final secureStore = _MemorySecureStore();
    final tabs = List.generate(
      7,
      (index) => <String, Object?>{
        'id': 'tab-$index',
        'url': 'https://example.com/$index',
        'title': 'Tab $index',
      },
    )..insert(0, <String, Object?>{'id': '', 'url': 'javascript:alert(1)'});
    await secureStore.write(
      key: 'discover_tabs_v1_MHhhYmM=',
      value: jsonEncode(<String, Object?>{
        'version': 1,
        'activeTabId': 'missing',
        'tabs': tabs,
      }),
    );

    final snapshot = await DiscoverTabStorage(
      secureStore: secureStore,
    ).load(maxTabs: 5, scopeKey: '0xabc');

    expect(snapshot, isNotNull);
    expect(snapshot!.tabs.length, 5);
    expect(snapshot.activeTabId, snapshot.tabs.first.id);

    expect(
      await DiscoverTabStorage(
        secureStore: secureStore,
      ).load(maxTabs: 5, scopeKey: '0xdef'),
      isNull,
    );
  });
}
