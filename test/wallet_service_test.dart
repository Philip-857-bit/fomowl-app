import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

void main() {
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
