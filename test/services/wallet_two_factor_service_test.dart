import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/http_client_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_backend_auth_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/wallet_two_factor_service.dart';

const _walletA = '0x1111111111111111111111111111111111111111';
const _walletB = '0x2222222222222222222222222222222222222222';

class _FakeStorageService extends StorageService {
  String? authority;

  @override
  Future<String?> getTwoFactorAuthorityWallet() async => authority;

  @override
  Future<void> setTwoFactorAuthorityWallet(String walletAddress) async {
    authority = walletAddress.toLowerCase();
  }
}

class _FakeWalletService extends WalletService {
  _FakeWalletService(this.currentWallet);

  String currentWallet;

  @override
  Future<String?> getCurrentWalletAddress() async => currentWallet;

  @override
  Future<List<WalletAccount>> getWalletAccounts() async => [
    WalletAccount(
      address: _walletA,
      name: 'Wallet A',
      origin: WalletOrigin.imported,
      createdAt: DateTime.utc(2026),
    ),
    WalletAccount(
      address: _walletB,
      name: 'Wallet B',
      origin: WalletOrigin.imported,
      createdAt: DateTime.utc(2026),
    ),
  ];
}

class _FakeWalletBackendAuthService extends WalletBackendAuthService {
  @override
  Future<http.Response> sendAuthorized(
    String walletAddress,
    Future<http.Response> Function(Map<String, String> headers) send,
    Map<String, String> headers,
  ) {
    return send({...headers, 'x-test-wallet': walletAddress.toLowerCase()});
  }
}

class _FakeHttpClientService extends HttpClientService {
  _FakeHttpClientService(this._testClient) : super.internal();

  final http.Client _testClient;

  @override
  http.Client get client => _testClient;
}

void main() {
  test(
    'discovers an existing setup and keeps it after active-wallet changes',
    () async {
      final requestedWallets = <String>[];
      final client = MockClient((request) async {
        final wallet = request.headers['x-test-wallet']!;
        requestedWallets.add(wallet);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'enabled': wallet == _walletB, 'pending_setup': false},
          }),
          200,
        );
      });
      final storage = _FakeStorageService();
      final wallets = _FakeWalletService(_walletA);
      final service = WalletTwoFactorService(
        storageService: storage,
        walletService: wallets,
        walletBackendAuthService: _FakeWalletBackendAuthService(),
        httpClientService: _FakeHttpClientService(client),
      );

      final migratedStatus = await service.fetchTwoFactorStatus();
      expect(migratedStatus['enabled'], isTrue);
      expect(storage.authority, _walletB);

      requestedWallets.clear();
      wallets.currentWallet = _walletA;
      final statusAfterSwitch = await service.fetchTwoFactorStatus();

      expect(statusAfterSwitch['enabled'], isTrue);
      expect(requestedWallets, [_walletB]);
    },
  );

  test('uses the persisted authority for authenticator confirmation', () async {
    final requestedWallets = <String>[];
    final client = MockClient((request) async {
      requestedWallets.add(request.headers['x-test-wallet']!);
      return http.Response(jsonEncode({'success': true}), 200);
    });
    final storage = _FakeStorageService()..authority = _walletB;
    final service = WalletTwoFactorService(
      storageService: storage,
      walletService: _FakeWalletService(_walletA),
      walletBackendAuthService: _FakeWalletBackendAuthService(),
      httpClientService: _FakeHttpClientService(client),
    );

    final result = await service.confirmTwoFactorCode(code: '123456');

    expect(result['success'], isTrue);
    expect(requestedWallets, [_walletB]);
  });
}
