import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/screens/swap/swap_screen_helpers.dart';
import 'package:fomowl_wallet/models/token.dart';

void main() {
  Token token(
    String symbol, {
    String? address,
    String? networkKey = 'evm:56',
  }) => Token(
    symbol: symbol,
    name: symbol,
    contractAddress: address,
    balance: 0,
    valueUsd: 0,
    changePercent24h: 0,
    networkKey: networkKey,
  );

  group('swap token pairing', () {
    test('recognizes stablecoins case-insensitively', () {
      expect(isSwapStablecoin(token('usdt', address: '0x1')), isTrue);
      expect(isSwapStablecoin(token('FDUSD', address: '0x2')), isTrue);
      expect(isSwapStablecoin(token('SOL')), isFalse);
    });

    test('identity requires the same asset and compatible network', () {
      expect(
        swapTokensAreIdentical(
          token('USDT', address: '0xABC'),
          token('Other', address: '0xabc'),
        ),
        isTrue,
      );
      expect(
        swapTokensAreIdentical(
          token('USDT', address: '0xabc'),
          token('USDT', address: '0xabc', networkKey: 'evm:1'),
        ),
        isFalse,
      );
    });

    test('counter token prefers native when selling a contract token', () {
      final usdt = token('USDT', address: '0x1');
      final native = token('BNB');
      final other = token('OWL', address: '0x2');
      expect(defaultSwapCounterToken(usdt, [usdt, other, native]), native);
    });

    test('counter token prefers stablecoin when selling native', () {
      final native = token('BNB');
      final other = token('OWL', address: '0x2');
      final usdt = token('USDT', address: '0x1');
      expect(defaultSwapCounterToken(native, [native, other, usdt]), usdt);
    });

    test('hides native RWA and WRWA on Asset Chain swap', () {
      final nativeRwa = token('RWA', networkKey: 'evm:42420');
      final wrwa = token(
        'WRWA',
        address: '0x2584d40b5553e81bb9dec0b6cd1a2e504aab1709',
        networkKey: 'evm:42420',
      );
      final shalom = token(
        'SHALOM',
        address: '0xf20f989CAf263C513f9183B4Fed88F14Fc04c8dB',
        networkKey: 'evm:42420',
      );
      expect(isSwapEligibleTokenForChain(nativeRwa, 42420), isFalse);
      expect(isSwapEligibleTokenForChain(wrwa, 42420), isFalse);
      expect(isSwapEligibleTokenForChain(shalom, 42420), isTrue);
      expect(isSwapEligibleTokenForChain(token('BNB'), 56), isTrue);
    });
  });

  group('looksLikeTxHash', () {
    test('accepts a 0x-prefixed 32-byte hash', () {
      expect(looksLikeTxHash('0x${'a' * 64}'), isTrue);
      expect(looksLikeTxHash('0x${'A1b2' * 16}'), isTrue);
    });

    test('rejects wrong length, missing prefix and non-hex', () {
      expect(looksLikeTxHash('0x${'a' * 63}'), isFalse);
      expect(looksLikeTxHash('0x${'a' * 65}'), isFalse);
      expect(looksLikeTxHash('a' * 64), isFalse);
      expect(looksLikeTxHash('0x${'z' * 64}'), isFalse);
      expect(looksLikeTxHash(''), isFalse);
    });
  });

  group('looksLikeSolanaPublicKey', () {
    test('accepts base58 keys of length 32-44 and trims whitespace', () {
      expect(
        looksLikeSolanaPublicKey(
          '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM',
        ),
        isTrue,
      );
      expect(
        looksLikeSolanaPublicKey(
          '  9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM  ',
        ),
        isTrue,
      );
    });

    test('rejects too-short, too-long and non-base58 characters', () {
      expect(looksLikeSolanaPublicKey('short'), isFalse);
      expect(looksLikeSolanaPublicKey('1' * 45), isFalse);
      // 0, O, I and l are not in the base58 alphabet.
      expect(looksLikeSolanaPublicKey('0OIl${'1' * 28}'), isFalse);
    });
  });

  group('shortHash', () {
    test('abbreviates long hashes as 0x1234...abcd', () {
      expect(shortHash('0x1234567890abcdef'), '0x1234...cdef');
    });

    test('returns short strings unchanged', () {
      expect(shortHash('0x1234'), '0x1234');
      expect(shortHash('0x12345678'), '0x12345678');
    });
  });

  group('swap error classification', () {
    test(
      'isSolanaSwapBalanceError requires a balance signal and a swap context',
      () {
        expect(
          isSolanaSwapBalanceError('insufficient funds for jupiter swap'),
          isTrue,
        );
        expect(
          isSolanaSwapBalanceError('not enough sol to cover quote'),
          isTrue,
        );
        // A generic EVM swap failure must not be relabelled as SOL.
        expect(
          isSolanaSwapBalanceError(
            'swap failed: insufficient funds for gas * price + value',
          ),
          isFalse,
        );
        // Balance signal without swap context.
        expect(isSolanaSwapBalanceError('insufficient funds'), isFalse);
        // No balance signal at all.
        expect(isSolanaSwapBalanceError('jupiter swap failed'), isFalse);
      },
    );

    test('isSolanaSwapAddressError requires an address signal and context', () {
      expect(
        isSolanaSwapAddressError('invalid taker for jupiter swap'),
        isTrue,
      );
      expect(
        isSolanaSwapAddressError('selected solana wallet address is invalid'),
        isTrue,
      );
      expect(isSolanaSwapAddressError('valid public key'), isFalse);
      expect(isSolanaSwapAddressError('jupiter swap ok'), isFalse);
    });

    test(
      'isSwapPriceMovementError requires slippage/price wording + context',
      () {
        expect(isSwapPriceMovementError('slippage exceeded on swap'), isTrue);
        expect(isSwapPriceMovementError('price movement during quote'), isTrue);
        expect(isSwapPriceMovementError('slippage tolerance'), isFalse);
        expect(isSwapPriceMovementError('swap failed'), isFalse);
      },
    );
  });

  group('amount parsing and formatting', () {
    test('parseDecimalAmount strips commas and tolerates bad input', () {
      expect(parseDecimalAmount('1,234.5'), Decimal.parse('1234.5'));
      expect(parseDecimalAmount('  42 '), Decimal.parse('42'));
      expect(parseDecimalAmount(''), Decimal.zero);
      expect(parseDecimalAmount('not a number'), Decimal.zero);
    });

    test('toWeiAmount scales by decimals and rejects empty/invalid', () {
      expect(toWeiAmount('1', 6), '1000000');
      expect(toWeiAmount('1.5', 2), '150');
      expect(toWeiAmount('1,000', 0), '1000');
      expect(toWeiAmount('', 18), isNull);
      expect(toWeiAmount('abc', 18), isNull);
    });

    test('formatDecimalInput truncates and trims trailing zeros', () {
      expect(formatDecimalInput(Decimal.parse('1.23456'), 2), '1.23');
      expect(formatDecimalInput(Decimal.parse('1.20000'), 4), '1.2');
      expect(formatDecimalInput(Decimal.parse('5.0'), 4), '5');
      expect(formatDecimalInput(Decimal.parse('7'), 4), '7');
    });
  });

  group('gasless response parsing', () {
    test('extractGaslessStatusValue checks top-level then trade/result', () {
      expect(extractGaslessStatusValue({'status': 'confirmed'}), 'confirmed');
      expect(
        extractGaslessStatusValue({
          'trade': {'status': 'pending'},
        }),
        'pending',
      );
      expect(
        extractGaslessStatusValue({
          'result': {'status': 'submitted'},
        }),
        'submitted',
      );
      expect(extractGaslessStatusValue({'other': 1}), isNull);
    });

    test('extractGaslessTxHash finds explicit keys and nested tx lists', () {
      final hash = '0x${'a' * 64}';
      expect(extractGaslessTxHash({'txHash': hash}), hash);
      expect(
        extractGaslessTxHash({
          'trade': {'settlementTxHash': hash},
        }),
        hash,
      );
      expect(
        extractGaslessTxHash({
          'result': {
            'transactions': [
              {'hash': hash},
            ],
          },
        }),
        hash,
      );
      // A non-hash value must not be returned.
      expect(extractGaslessTxHash({'txHash': 'order-123'}), isNull);
      expect(extractGaslessTxHash({'nothing': true}), isNull);
    });
  });
}
