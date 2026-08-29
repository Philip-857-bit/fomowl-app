import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

void main() {
  setUpAll(() async {
    try {
      await RustLib.init();
    } catch (_) {}
  });

  test('normalizeMnemonic collapses whitespace and lowercases', () {
    final walletService = WalletService();
    final normalized = walletService.normalizeMnemonic(
      '  Abandon   ability\nable\tabout  above absent absorb abstract absurd abuse access accident  ',
    );

    expect(
      normalized,
      'abandon ability able about above absent absorb abstract absurd abuse access accident',
    );
  });

  test('normalizeMnemonic handles numbered and punctuated phrase pastes', () {
    final walletService = WalletService();
    final normalized = walletService.normalizeMnemonic(
      '1. Abandon, 2) abandon; 3: abandon\n4 - abandon 5. abandon '
      '6) abandon 7: abandon 8. abandon 9) abandon 10: abandon '
      '11. abandon 12) about',
    );

    expect(
      normalized,
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
  });

  test(
    'validateMnemonic accepts valid phrases pasted with irregular spacing',
    () async {
      const pasted =
          ' abandon   abandon\nabandon\tabandon abandon abandon abandon abandon abandon abandon abandon about ';

      expect(await WalletService().validateMnemonic(pasted), isTrue);
    },
  );

  group('Solana base58 helpers', () {
    test('decodeBase58Bytes accepts 32-byte seed material', () {
      final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final encoded = WalletService.encodeBase58Bytes(bytes);

      expect(WalletService.decodeBase58Bytes(encoded), orderedEquals(bytes));
      expect(
        () => WalletService.decodeBase58Signature(encoded),
        throwsFormatException,
      );
    });

    test('decodeBase58Signature still requires a 64-byte signature', () {
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final encoded = WalletService.encodeBase58Bytes(bytes);

      expect(
        WalletService.decodeBase58Signature(encoded),
        orderedEquals(bytes),
      );
    });
  });

  group('importWalletFromPrivateKey validation', () {
    late WalletService walletService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      walletService = WalletService(
        storageService: StorageService(
          secureStore: _InMemorySecureStore(),
          sharedPreferences: prefs,
        ),
      );
    });

    test('rejects key that is too short', () {
      expect(
        () => walletService.importWalletFromPrivateKey('abc123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid private key'),
          ),
        ),
      );
    });

    test('rejects key containing non-hex characters', () {
      // 64 characters but contains 'g' which is not a valid hex character
      const nonHexKey =
          'gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg';
      expect(
        () => walletService.importWalletFromPrivateKey(nonHexKey),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid private key'),
          ),
        ),
      );
    });

    test('rejects key that is too long', () {
      // 66 characters (valid hex but wrong length)
      const longKey =
          'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabb';
      expect(
        () => walletService.importWalletFromPrivateKey(longKey),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid private key'),
          ),
        ),
      );
    });

    test(
      'accepts a valid 64-character hex key and derives EIP-55 address',
      () async {
        // Hardhat default account #0 — well-known test key, safe to use in tests
        const validKey =
            'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
        final result = await walletService.importWalletFromPrivateKey(validKey);
        expect(result['address'], isNotEmpty);
        // Ethereum addresses are 42 chars including 0x prefix
        expect(result['address']!.length, 42);
        expect(result['address'], startsWith('0x'));
      },
    );
  });

  group('active family addresses', () {
    late WalletService walletService;
    late StorageService storage;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(
        secureStore: _InMemorySecureStore(),
        sharedPreferences: prefs,
      );
      walletService = WalletService(storageService: storage);
    });

    test('returns EVM, Solana, and Tron addresses for a seed wallet', () async {
      await storage.saveWallet(
        address: '0x1234567890123456789012345678901234567890',
        privateKey: 'private-key',
        walletName: 'Wallet 1',
        origin: WalletOrigin.derived,
        derivationIndex: 0,
        seedGroupId: 'seed_alpha',
        addressesByFamily: const {
          ChainFamily.solana: 'solanaAddress',
          ChainFamily.tron: 'tronAddress',
        },
      );

      expect(
        await walletService.getActiveAddressForFamily(ChainFamily.evm),
        '0x1234567890123456789012345678901234567890',
      );
      expect(
        await walletService.getActiveAddressForFamily(ChainFamily.solana),
        'solanaAddress',
      );
      expect(
        await walletService.getActiveAddressForFamily(ChainFamily.tron),
        'tronAddress',
      );
    });

    test(
      'returns null for unsupported families on private-key imports',
      () async {
        await storage.saveWallet(
          address: 'solanaAddress',
          privateKey: 'solana-private-key',
          walletName: 'Imported Solana',
          origin: WalletOrigin.imported,
          addressesByFamily: const {ChainFamily.solana: 'solanaAddress'},
        );

        expect(
          await walletService.getActiveAddressForFamily(ChainFamily.solana),
          'solanaAddress',
        );
        expect(
          await walletService.getActiveAddressForFamily(ChainFamily.evm),
          isNull,
        );
        expect(
          await walletService.getActiveAddressForFamily(ChainFamily.tron),
          isNull,
        );
      },
    );
  });

  group('chain-specific private-key export', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    test(
      'exports distinct EVM, Solana, and Tron keys that reproduce each address',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = StorageService(
          secureStore: _InMemorySecureStore(),
          sharedPreferences: prefs,
        );
        final walletService = WalletService(storageService: storage);

        try {
          await walletService.createWalletFromMnemonic(mnemonic);
        } catch (_) {
          return; // Skip if FFI is not available
        }
        final account = await walletService.getActiveWalletAccount();
        expect(account, isNotNull);

        final evmKey = await walletService.exportPrivateKeyForFamily(
          account!,
          ChainFamily.evm,
        );
        final solanaKey = await walletService.exportPrivateKeyForFamily(
          account,
          ChainFamily.solana,
        );
        final tronKey = await walletService.exportPrivateKeyForFamily(
          account,
          ChainFamily.tron,
        );

        expect(evmKey, matches(RegExp(r'^[0-9a-fA-F]{64}$')));
        expect(tronKey, matches(RegExp(r'^[0-9a-fA-F]{64}$')));
        expect(tronKey, isNot(evmKey));
        expect(WalletService.decodeBase58Bytes(solanaKey), hasLength(64));

        SharedPreferences.setMockInitialValues({});
        final importPrefs = await SharedPreferences.getInstance();
        final importedWalletService = WalletService(
          storageService: StorageService(
            secureStore: _InMemorySecureStore(),
            sharedPreferences: importPrefs,
          ),
        );
        final imported = await importedWalletService.importWalletFromSolanaKey(
          solanaKey,
        );
        expect(
          imported['address'],
          account.getWalletAddressForFamily(ChainFamily.solana),
        );
      },
    );

    test('duplicate EVM import cannot replace a seed-backed account', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(
        secureStore: _InMemorySecureStore(),
        sharedPreferences: prefs,
      );
      final walletService = WalletService(storageService: storage);

      try {
        await walletService.createWalletFromMnemonic(mnemonic);
      } catch (_) {
        return; // Skip if FFI is not available
      }
      final original = (await walletService.getActiveWalletAccount())!;
      final evmKey = await walletService.exportPrivateKeyForFamily(
        original,
        ChainFamily.evm,
      );

      await expectLater(
        walletService.importWalletFromPrivateKey(
          evmKey,
          walletName: 'Duplicate import',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('already in Owllet'),
          ),
        ),
      );

      final accounts = await walletService.getWalletAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.origin, WalletOrigin.derived);
      expect(accounts.single.seedGroupId, original.seedGroupId);
      expect(accounts.single.addressesByFamily.keys, {
        ChainFamily.evm,
        ChainFamily.solana,
        ChainFamily.tron,
      });
      expect(await walletService.getCurrentWalletAddress(), original.address);
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
