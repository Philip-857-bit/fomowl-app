import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletBackendAuthService', () {
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

    test('reuses cached wallet session headers when still valid', () async {
      const wallet = '0x1234567890123456789012345678901234567890';
      await storage.saveBackendSession(
        walletAddress: wallet,
        token: 'cached-token',
        expiresAt: '2099-03-08T12:00:00Z',
      );

      final service = WalletBackendAuthService(
        storageService: storage,
        walletService: _NoopWalletService(),
      );

      late Map<String, String> seenHeaders;
      final response = await service.sendAuthorized(wallet, (headers) async {
        seenHeaders = headers;
        return http.Response('{}', 200);
      }, {'Content-Type': 'application/json'});

      expect(response.statusCode, 200);
      expect(seenHeaders['Authorization'], 'Bearer cached-token');
      expect(seenHeaders['Content-Type'], 'application/json');
    });
  });
}

class _NoopWalletService extends WalletService {}

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
