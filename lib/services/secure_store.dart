import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStore {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

/// Shared iOS keychain options for all secret storage. `first_unlock_this_device`
/// keeps secrets off iCloud keychain sync and out of encrypted device backups,
/// while still allowing background access after the first unlock.
const IOSOptions kSecureIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

class FlutterSecureStoreAdapter implements SecureStore {
  const FlutterSecureStoreAdapter([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: kSecureIosOptions,
    ),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}
