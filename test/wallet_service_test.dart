import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/services/wallet_service.dart';

void main() {
  final walletService = WalletService();

  test('normalizeMnemonic collapses whitespace and lowercases', () {
    final normalized = walletService.normalizeMnemonic(
      '  Abandon   ability\nable\tabout  above absent absorb abstract absurd abuse access accident  ',
    );

    expect(
      normalized,
      'abandon ability able about above absent absorb abstract absurd abuse access accident',
    );
  });

  test(
    'validateMnemonic accepts valid phrases pasted with irregular spacing',
    skip: 'Requires Rust FFI initialized',
    () async {
      const pasted =
          ' abandon   abandon\nabandon\tabandon abandon abandon abandon abandon abandon abandon abandon about ';

      expect(await walletService.validateMnemonic(pasted), isTrue);
    },
  );

  group('importWalletFromPrivateKey validation', () {
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
      'accepts a valid 64-character hex key',
      skip: 'Requires Rust FFI initialized',
      () async {
        // A known valid Ethereum private key (test/example key only)
        const validKey =
            'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
        final result = await walletService.importWalletFromPrivateKey(validKey);
        expect(result['address'], isNotEmpty);
      },
    );
  });
}
