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
    () {
      const pasted =
          ' abandon   abandon\nabandon\tabandon abandon abandon abandon abandon abandon abandon abandon about ';

      expect(walletService.validateMnemonic(pasted), isTrue);
    },
  );
}
