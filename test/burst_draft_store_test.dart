import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fomowl_wallet/features/burst/burst_draft_store.dart';

class MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  test('persists draft only for its account, wallet, and network', () async {
    final storage = MemoryStorage();
    final store = BurstDraftStore(storage: storage);
    await store.write('account-a', '0xABC', 56, {
      'request': {'idempotencyKey': 'one'},
      'prepared': {'joinCode': 'ABC'},
    });
    expect(
      (await store.read('account-a', '0xabc', 56))?['prepared']['joinCode'],
      'ABC',
    );
    expect(await store.read('account-b', '0xabc', 56), isNull);
    expect(await store.read('account-a', '0xdef', 56), isNull);
    expect(await store.read('account-a', '0xabc', 1), isNull);
    await store.clear('account-a', '0xabc', 56);
    expect(await store.read('account-a', '0xabc', 56), isNull);
  });
}
