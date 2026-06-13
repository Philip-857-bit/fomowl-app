import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/utils/token_visibility_utils.dart';

Token _token({
  required String symbol,
  String? address,
  String? networkKey,
}) {
  return Token(
    symbol: symbol,
    name: symbol,
    contractAddress: address,
    balance: 0,
    valueUsd: 0,
    changePercent24h: 0,
    networkKey: networkKey,
  );
}

void main() {
  group('TokenVisibilityUtils.contains', () {
    test(
      'hides a token even when it is later seen without a networkKey scope '
      '(Send/Swap pickers merge sources that drop the scope)',
      () {
        // Hidden from a context that has the scope (e.g. token management).
        final hidden = _token(
          symbol: 'SPAM',
          address: '0xAbCdEf0000000000000000000000000000000001',
          networkKey: 'evm:1',
        );
        final stored = {TokenVisibilityUtils.identifier(hidden)};
        expect(stored, contains('evm:1:0xabcdef0000000000000000000000000000000001'));

        // The same token arriving from the suggested list without a scope.
        final sameTokenNoScope = _token(
          symbol: 'SPAM',
          address: '0xABCDEF0000000000000000000000000000000001',
        );
        expect(
          TokenVisibilityUtils.contains(stored, sameTokenNoScope),
          isTrue,
          reason: 'address-only legacy id must still match the scoped hidden id',
        );
      },
    );

    test('hides a token presented with the same scope', () {
      final hidden = _token(
        symbol: 'SPAM',
        address: '0xabc0000000000000000000000000000000000002',
        networkKey: 'evm:1',
      );
      final stored = {TokenVisibilityUtils.identifier(hidden)};
      expect(TokenVisibilityUtils.contains(stored, hidden), isTrue);
    });

    test('does not hide a different token with a different address', () {
      final hidden = _token(
        symbol: 'SPAM',
        address: '0xabc0000000000000000000000000000000000003',
        networkKey: 'evm:1',
      );
      final stored = {TokenVisibilityUtils.identifier(hidden)};
      final other = _token(
        symbol: 'REAL',
        address: '0xdef0000000000000000000000000000000000009',
        networkKey: 'evm:1',
      );
      expect(TokenVisibilityUtils.contains(stored, other), isFalse);
    });

    test('legacy (unscoped) stored ids still match', () {
      final token = _token(
        symbol: 'SPAM',
        address: '0xabc0000000000000000000000000000000000004',
        networkKey: 'evm:1',
      );
      final stored = {TokenVisibilityUtils.legacyIdentifier(token)};
      expect(TokenVisibilityUtils.contains(stored, token), isTrue);
    });

    test('hides a native token across scope differences', () {
      final hiddenNative = _token(symbol: 'ETH', networkKey: 'evm:1');
      final stored = {TokenVisibilityUtils.identifier(hiddenNative)};
      final nativeNoScope = _token(symbol: 'eth');
      expect(TokenVisibilityUtils.contains(stored, nativeNoScope), isTrue);
    });
  });
}
