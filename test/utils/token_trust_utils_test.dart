import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/utils/token_trust_utils.dart';

Token token({
  required String symbol,
  String? address,
  bool isCertified = false,
}) => Token(
  symbol: symbol,
  name: symbol,
  contractAddress: address,
  balance: 0,
  valueUsd: 0,
  changePercent24h: 0,
  isCertified: isCertified,
);

void main() {
  group('TokenTrustUtils', () {
    test('recognizes canonical BSC USDT even without backend metadata', () {
      final result = TokenTrustUtils.levelFor(
        token(
          symbol: 'USDT',
          address: '0x55d398326f99059fF775485246999027B3197955',
        ),
        chainId: 56,
      );

      expect(result, TokenTrustLevel.verified);
    });

    test('marks a noncanonical protected stablecoin symbol suspicious', () {
      final result = TokenTrustUtils.levelFor(
        token(
          symbol: 'USDT',
          address: '0x1111111111111111111111111111111111111111',
        ),
        chainId: 56,
      );

      expect(result, TokenTrustLevel.suspicious);
      expect(
        TokenTrustUtils.blocksDestination(
          token(
            symbol: 'USDT',
            address: '0x1111111111111111111111111111111111111111',
          ),
          chainId: 56,
        ),
        isTrue,
      );
    });

    test('allows certified and native tokens as destinations', () {
      expect(
        TokenTrustUtils.blocksDestination(
          token(
            symbol: 'OWL',
            address: '0x2222222222222222222222222222222222222222',
            isCertified: true,
          ),
          chainId: 56,
        ),
        isFalse,
      );
      expect(
        TokenTrustUtils.blocksDestination(token(symbol: 'BNB'), chainId: 56),
        isFalse,
      );
    });

    test('recognizes canonical Solana stablecoins', () {
      expect(
        TokenTrustUtils.levelFor(
          token(
            symbol: 'USDC',
            address: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          ),
          chainId: -501,
        ),
        TokenTrustLevel.verified,
      );
    });

    test('accepts canonical Base USDT and rejects the former typo', () {
      expect(
        TokenTrustUtils.levelFor(
          token(
            symbol: 'USDT',
            address: '0xfde4c96c8593536e31f229ea8f37b2ada2699bb2',
          ),
          chainId: 8453,
        ),
        TokenTrustLevel.verified,
      );
      expect(
        TokenTrustUtils.levelFor(
          token(
            symbol: 'USDT',
            address: '0xfde4c96c8593536e31f229ea8f37b2ad0a5b2296',
          ),
          chainId: 8453,
        ),
        TokenTrustLevel.suspicious,
      );
    });

    test('warns but does not hard-block a generic unverified token', () {
      final unknown = token(
        symbol: 'OWL',
        address: '0x3333333333333333333333333333333333333333',
      );
      expect(
        TokenTrustUtils.levelFor(unknown, chainId: 56),
        TokenTrustLevel.unverified,
      );
      expect(TokenTrustUtils.blocksDestination(unknown, chainId: 56), isFalse);
    });
  });
}
