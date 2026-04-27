import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
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

    test('persists backend wallet sessions by wallet address', () async {
      const walletAddress = '0x1234567890123456789012345678901234567890';
      await storage.saveBackendSession(
        walletAddress: walletAddress,
        token: 'session-token',
        expiresAt: '2026-03-08T12:00:00Z',
      );

      final session = await storage.getBackendSession(walletAddress);
      expect(session, isNotNull);
      expect(session!['token'], 'session-token');
      expect(session['expiresAt'], '2026-03-08T12:00:00Z');

      await storage.clearBackendSession(walletAddress);
      expect(await storage.getBackendSession(walletAddress), isNull);
    });

    test('persists wallet account family addresses', () async {
      await storage.saveWallet(
        address: '0x1234567890123456789012345678901234567890',
        privateKey: 'private-key',
        walletName: 'Wallet 1',
        origin: WalletOrigin.derived,
        derivationIndex: 0,
        addressesByFamily: const {
          ChainFamily.solana: 'solanaAddress',
          ChainFamily.tron: 'tronAddress',
        },
      );

      final accounts = await storage.getWalletAccounts();
      expect(accounts, hasLength(1));
      expect(
        accounts.single.getWalletAddressForFamily(ChainFamily.evm),
        '0x1234567890123456789012345678901234567890',
      );
      expect(
        accounts.single.getWalletAddressForFamily(ChainFamily.solana),
        'solanaAddress',
      );
      expect(
        accounts.single.getWalletAddressForFamily(ChainFamily.tron),
        'tronAddress',
      );
    });

    test('rust and dart argon2 derivation stay compatible', () async {
      final saltBytes = Uint8List.fromList(
        List<int>.generate(16, (i) => i + 1),
      );
      final salt = base64Encode(saltBytes);

      final rustHash = await storage.derivePasscodeHashForTest(
        passcode: '123456',
        salt: salt,
        iterations: 3,
        memoryPowerOf2: 16,
      );
      final dartHash = storage.derivePasscodeHashDartForTest(
        passcode: '123456',
        salt: salt,
        iterations: 3,
        memoryPowerOf2: 16,
      );

      expect(rustHash, dartHash);
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
