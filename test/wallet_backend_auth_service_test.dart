import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';
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

    test('production affiliate authenticates and caches separately', () async {
      const wallet = '0x1234567890123456789012345678901234567890';
      await storage.saveBackendSession(
        walletAddress: wallet,
        token: 'staging-token',
        expiresAt: '2099-03-08T12:00:00Z',
      );
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.path.endsWith('/challenge')) {
          return http.Response(
            '{"challenge":"nonce","message":"sign me"}',
            200,
          );
        }
        expect(request.body, contains('"signature":"0xsigned"'));
        return http.Response(
          '{"token":"production-token","expiresAt":"2099-03-08T12:00:00Z"}',
          200,
        );
      });
      final service = WalletBackendAuthService.productionAffiliate(
        walletService: _NoopWalletService(),
        httpClientService: _TestHttpClientService(client),
      );

      expect(await service.ensureWalletSession(wallet), 'production-token');
      expect(await service.ensureWalletSession(wallet), 'production-token');
      expect(requests, [
        Uri.parse('https://core.owlletapp.com/api/settings/auth/challenge'),
        Uri.parse('https://core.owlletapp.com/api/settings/auth/verify'),
      ]);
      await service.invalidateSession(wallet);
      expect(await service.getValidSessionToken(wallet), isNull);
      expect(
        (await storage.getBackendSession(wallet))?['token'],
        'staging-token',
      );
    });
  });
}

class _NoopWalletService extends WalletService {
  @override
  Future<String> signMessageForAddress(String? address, String message) async =>
      'signed';
}

class _TestHttpClientService extends HttpClientService {
  _TestHttpClientService(this.client) : super.internal();

  @override
  final http.Client client;
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
