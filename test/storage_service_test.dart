import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService passcode handling', () {
    late StorageService storage;
    late _InMemorySecureStore secureStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStore = _InMemorySecureStore();
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(
        secureStore: secureStore,
        sharedPreferences: prefs,
      );
    });

    test('stores hashed verifier instead of raw passcode', () async {
      await storage.savePasscode('123456');

      final stored = await secureStore.read(key: 'user_passcode');
      expect(stored, isNotNull);
      expect(stored, isNot('123456'));

      final decoded = jsonDecode(stored!) as Map<String, dynamic>;
      expect(decoded['salt'], isNotEmpty);
      expect(decoded['hash'], isNotEmpty);
      expect(decoded['version'], 2);
    });

    test('verifies legacy raw passcode and migrates it', () async {
      await secureStore.write(key: 'user_passcode', value: '123456');

      expect(await storage.verifyPasscode('123456'), isTrue);

      final migrated = await secureStore.read(key: 'user_passcode');
      expect(migrated, isNotNull);
      expect(migrated, isNot('123456'));
    });
  });
}

class _InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
