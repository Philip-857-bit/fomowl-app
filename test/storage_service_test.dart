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

    test(
      'recovers seed phrase from any account in the same seed group',
      () async {
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        await storage.saveWallet(
          address: '0x1111111111111111111111111111111111111111',
          privateKey: 'private-key-1',
          mnemonic: mnemonic,
          walletName: 'Wallet 1',
          origin: WalletOrigin.derived,
          derivationIndex: 0,
          seedGroupId: 'seed_alpha',
        );
        await storage.saveWallet(
          address: '0x2222222222222222222222222222222222222222',
          privateKey: 'private-key-2',
          walletName: 'Wallet 2',
          origin: WalletOrigin.derived,
          derivationIndex: 1,
          seedGroupId: 'seed_alpha',
        );

        expect(
          await storage.getMnemonic(
            '0x2222222222222222222222222222222222222222',
          ),
          mnemonic,
        );
        expect(await storage.getMnemonicForSeedGroup('seed_alpha'), mnemonic);
      },
    );

    test('clearAll wipes wallet, passcode, mnemonic, and prefs caches', () async {
      final prefs = await SharedPreferences.getInstance();
      await storage.saveWallet(
        address: '0x1234567890123456789012345678901234567890',
        privateKey: 'private-key',
        mnemonic:
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        walletName: 'Wallet 1',
        origin: WalletOrigin.derived,
        derivationIndex: 0,
        seedGroupId: 'seed_alpha',
      );
      await storage.savePasscode('123456');
      await storage.setEnabledChainFamilies({
        ChainFamily.evm,
        ChainFamily.solana,
      });
      await prefs.setStringList('hidden_tokens_-501', ['solana:mainnet:mint']);
      await prefs.setString('custom_tokens_v1', '{"-501":[]}');

      await storage.clearAll();

      expect(await storage.getWalletAddress(), isNull);
      expect(await storage.getMnemonic(), isNull);
      expect(await storage.getMnemonicForSeedGroup('seed_alpha'), isNull);
      expect(await storage.getWalletAccounts(), isEmpty);
      expect(await storage.hasPasscode(), isFalse);
      expect(prefs.getStringList('hidden_tokens_-501'), isNull);
      expect(prefs.getString('custom_tokens_v1'), isNull);
      expect(await storage.getEnabledChainFamilies(), isNull);
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
