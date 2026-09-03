import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/utils/token_visibility_utils.dart';

void main() {
  group('TokenVisibilityUtils', () {
    const defaultToken = Token(
      symbol: 'ETH',
      name: 'Ethereum',
      balance: 0,
      valueUsd: 0,
      changePercent24h: 0,
    );

    group('legacyIdentifier', () {
      test('returns lowercase contract address if present', () {
        final token = defaultToken.copyWith(contractAddress: '0x123ABC');
        expect(TokenVisibilityUtils.legacyIdentifier(token), '0x123abc');
      });

      test('returns native symbol format if no contract address', () {
        final token = defaultToken.copyWith(contractAddress: null);
        expect(TokenVisibilityUtils.legacyIdentifier(token), 'native_eth');
      });

      test('returns native symbol format if contract address is empty', () {
        final token = defaultToken.copyWith(contractAddress: '');
        expect(TokenVisibilityUtils.legacyIdentifier(token), 'native_eth');
      });
    });

    group('identifier', () {
      test('returns scoped legacy identifier if networkKey is present', () {
        final token = defaultToken.copyWith(
          contractAddress: '0x123ABC',
          networkKey: 'EVM:1',
        );
        expect(TokenVisibilityUtils.identifier(token), 'evm:1:0x123abc');
      });

      test('returns legacy identifier if no networkKey', () {
        final token = defaultToken.copyWith(contractAddress: '0x123ABC');
        expect(TokenVisibilityUtils.identifier(token), '0x123abc');
      });

      test('returns legacy identifier if networkKey is empty', () {
        final token = defaultToken.copyWith(
          contractAddress: '0x123ABC',
          networkKey: '  ',
        );
        expect(TokenVisibilityUtils.identifier(token), '0x123abc');
      });
    });

    group('identifiers', () {
      test('returns single legacy ID when unscoped', () {
        final token = defaultToken.copyWith(contractAddress: '0x123ABC');
        final ids = TokenVisibilityUtils.identifiers(token);
        expect(ids, {'0x123abc'});
      });

      test('returns both scoped and legacy IDs when scoped', () {
        final token = defaultToken.copyWith(
          contractAddress: '0x123ABC',
          networkKey: 'evm:1',
        );
        final ids = TokenVisibilityUtils.identifiers(token);
        expect(ids, {'evm:1:0x123abc', '0x123abc'});
      });
    });

    group('contains', () {
      test('returns true for exact match of current identifier', () {
        final token = defaultToken.copyWith(
          contractAddress: '0x123ABC',
          networkKey: 'evm:1',
        );
        expect(
          TokenVisibilityUtils.contains({'evm:1:0x123abc'}, token),
          isTrue,
        );
      });

      test('returns true for exact match of legacy identifier', () {
        final token = defaultToken.copyWith(
          contractAddress: '0x123ABC',
          networkKey: 'evm:1',
        );
        expect(TokenVisibilityUtils.contains({'0x123abc'}, token), isTrue);
      });

      test(
        'returns true for unscoped token against scoped ID in set (suffix match)',
        () {
          // Token in wallet/cache has NO networkKey
          final token = defaultToken.copyWith(contractAddress: '0x123ABC');
          // Set contains scoped ID
          expect(
            TokenVisibilityUtils.contains({'evm:1:0x123abc'}, token),
            isTrue,
          );
        },
      );

      test(
        'returns true for differently scoped token against scoped ID in set (suffix match)',
        () {
          // This is robust against e.g., EVM chain mismatches when token leaks
          final token = defaultToken.copyWith(
            contractAddress: '0x123ABC',
            networkKey: 'evm:137',
          );
          // Set contains scoped ID for a different chain
          expect(
            TokenVisibilityUtils.contains({'evm:1:0x123abc'}, token),
            isTrue,
          );
        },
      );

      test(
        'returns true for unscoped native token against scoped ID in set',
        () {
          final token = defaultToken.copyWith(symbol: 'ETH');
          expect(
            TokenVisibilityUtils.contains({'evm:1:native_eth'}, token),
            isTrue,
          );
        },
      );

      test('returns false when no IDs match', () {
        final token = defaultToken.copyWith(
          contractAddress: '0x123ABC',
          networkKey: 'evm:1',
        );
        expect(
          TokenVisibilityUtils.contains({'evm:1:0x999def', '0x999def'}, token),
          isFalse,
        );
      });
    });
  });
}
