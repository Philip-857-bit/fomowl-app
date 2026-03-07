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
  });
}
