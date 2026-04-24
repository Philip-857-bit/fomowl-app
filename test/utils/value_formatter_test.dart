import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/value_formatter.dart';
import 'package:decimal/decimal.dart';

void main() {
  group('ValueFormatter', () {
    setUp(() {
      ValueFormatter.setCurrencyCode('USD');
      ValueFormatter.updateUsdConversionRates({
        'USD': 1.0,
        'EUR': 0.92,
        'GBP': 0.79,
        'NGN': 1600.0,
      });
    });

    test('formats compact token amounts correctly (Trillions)', () {
      final value = Decimal.parse('1500000000000'); // 1.5 Trillion
      final result = ValueFormatter.formatCompactTokenAmount(
        value,
        symbol: 'ETH',
      );
      expect(result, '1.50T ETH');
    });

    test('formats compact token amounts correctly (Billions)', () {
      final value = Decimal.parse('244061880000'); // ~244 Billion
      final result = ValueFormatter.formatCompactTokenAmount(
        value,
        symbol: 'ETH',
      );
      expect(result, '244.06B ETH');
    });

    test('formats compact token amounts correctly (Millions)', () {
      final value = Decimal.parse('2500000'); // 2.5 Million
      final result = ValueFormatter.formatCompactTokenAmount(
        value,
        symbol: 'SOL',
      );
      expect(result, '2.50M SOL');
    });

    test('formats compact token amounts correctly (Thousands)', () {
      final value = Decimal.parse('1500'); // 1.5 Thousand
      final result = ValueFormatter.formatCompactTokenAmount(
        value,
        symbol: 'BTC',
      );
      expect(result, '1.50K BTC');
    });

    test('formats compact token amounts correctly (Sub-thousand)', () {
      final value = Decimal.parse('500.25');
      final result = ValueFormatter.formatCompactTokenAmount(
        value,
        symbol: 'USDC',
      );
      expect(result, '500.25 USDC');
    });

    test('formats USD value correctly with thresholds', () {
      expect(
        ValueFormatter.formatUsdValue(Decimal.parse('1500000000000.0')),
        '\$1.50T',
      );
      expect(
        ValueFormatter.formatUsdValue(Decimal.parse('244061880000.0')),
        '\$244.06B',
      );
      expect(
        ValueFormatter.formatUsdValue(Decimal.parse('2500000.0')),
        '\$2.50M',
      );
      expect(ValueFormatter.formatUsdValue(Decimal.parse('1500.0')), '\$1.50K');
      expect(
        ValueFormatter.formatUsdValue(Decimal.parse('500.25')),
        '\$500.25',
      );
    });

    test('converts USD values into the selected fiat currency', () {
      ValueFormatter.setCurrencyCode('NGN');

      expect(
        ValueFormatter.formatCurrencyWithGrouping(Decimal.one),
        'NGN 1,600.00',
      );
      expect(
        ValueFormatter.formatPlainFiatFromUsd(Decimal.parse('1.25')),
        '2000.00',
      );
    });

    test('converts selected fiat input back into USD', () {
      ValueFormatter.setCurrencyCode('NGN');

      expect(
        ValueFormatter.convertToUsdDecimal(Decimal.parse('1600')),
        Decimal.one,
      );
    });
  });
}
