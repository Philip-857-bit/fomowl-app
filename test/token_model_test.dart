import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/models/token.dart';

void main() {
  group('Token decimal-safe formatting', () {
    test('formats balances and values without raw double helpers', () {
      const token = Token(
        symbol: 'ETH',
        name: 'Ether',
        balance: 1.2345,
        valueUsd: 3456.78,
        priceUsd: 2800.123456,
        changePercent24h: 1.2,
      );

      expect(token.formattedBalance, '1.23 ETH');
      expect(token.formattedValue, '\$3.45K');
      expect(token.formattedPrice, '\$2800');
      expect(token.totalValueUsd, greaterThan(3456));
    });

    test('renders a positive unpriced holding as zero', () {
      const token = Token(
        symbol: 'NEW',
        name: 'New token',
        balance: 25,
        valueUsd: 0,
        priceUsd: 0,
        priceStatus: 'provider_error',
        changePercent24h: 0,
      );

      expect(token.formattedValue, '\$0');
      expect(token.formattedPrice, '\$0');
      expect(token.hasKnownPrice, isFalse);
      expect(token.hasProviderError, isTrue);
    });

    test('renders a missing price as unavailable instead of zero', () {
      const token = Token(
        symbol: 'RWA',
        name: 'Asset Chain',
        balance: 25,
        valueUsd: 0,
        priceUsd: 0,
        priceStatus: 'price_unavailable',
        changePercent24h: 0,
      );

      expect(token.formattedValue, '—');
      expect(token.formattedPrice, '—');
      expect(token.hasKnownPrice, isFalse);
    });

    test('recognizes DexScreener as a DEX price source', () {
      const token = Token(
        symbol: 'DEX',
        name: 'DEX token',
        balance: 1,
        valueUsd: 1,
        priceUsd: 1,
        priceStatus: 'found',
        priceSource: 'DexScreener',
        changePercent24h: 0,
      );

      expect(token.isDexPriced, isTrue);
    });
  });
}
