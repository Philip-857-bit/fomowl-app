import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/send_amount_conversion.dart';

void main() {
  for (final decimals in [0, 6, 8, 9, 18]) {
    test(
      'fiat conversion floors to actual token precision ($decimals decimals)',
      () {
        final conversion = SendAmountConversion(
          decimals: decimals,
          tokenUsdPrice: '3',
          usdToFiatRate: '1',
        );
        final scale = BigInt.from(10).pow(decimals);
        final units = conversion.fiatToBaseUnits('1.00');
        expect(units, scale ~/ BigInt.from(3));
        expect(units * BigInt.from(3), lessThanOrEqualTo(scale));
        expect((units + BigInt.one) * BigInt.from(3), greaterThan(scale));
      },
    );
  }
  test('Bitcoin USD input uses exact integer sats', () {
    final conversion = SendAmountConversion(
      decimals: 8,
      tokenUsdPrice: '60000',
      usdToFiatRate: '1',
    );
    expect(conversion.fiatToBaseUnits('25'), BigInt.from(41666));
    expect(conversion.baseUnitsToFiat(BigInt.from(100000)), '60.00');
  });
  test(
    'selected NGN/EUR/GBP exchange rates are applied before token conversion',
    () {
      for (final rate in ['1500', '0.92', '0.79']) {
        final conversion = SendAmountConversion(
          decimals: 8,
          tokenUsdPrice: '2',
          usdToFiatRate: rate,
        );
        expect(
          conversion.baseUnitsToFiat(BigInt.from(100000000)),
          {'1500': '3000.00', '0.92': '1.84', '0.79': '1.58'}[rate],
        );
      }
      final ngn = SendAmountConversion(
        decimals: 8,
        tokenUsdPrice: '60000',
        usdToFiatRate: '1500',
      );
      expect(ngn.fiatToBaseUnits('1,500.00'), BigInt.from(1666));
    },
  );
  test('holding-value price fallback never divides through doubles', () {
    final conversion = SendAmountConversion(
      decimals: 18,
      tokenUsdPrice: '0',
      tokenBalance: '3',
      tokenValueUsd: '1',
      usdToFiatRate: '1',
    );
    expect(
      conversion.fiatToBaseUnits('1'),
      BigInt.from(3) * BigInt.from(10).pow(18),
    );
  });
  test(
    'large, tiny and exponent-form price facts retain decimal precision',
    () {
      final conversion = SendAmountConversion(
        decimals: 18,
        tokenUsdPrice: '1e-18',
        usdToFiatRate: '1',
      );
      expect(conversion.fiatToBaseUnits('1'), BigInt.from(10).pow(36));
      expect(conversion.baseUnitsToFiat(BigInt.from(10).pow(36)), '1.00');
      final huge = SendAmountConversion(
        decimals: 18,
        tokenUsdPrice: '100000000000000000000',
        usdToFiatRate: '1',
      );
      expect(huge.fiatToBaseUnits('1'), BigInt.zero);
    },
  );
  test('invalid amounts and unavailable prices never produce a spend', () {
    final conversion = SendAmountConversion(
      decimals: 8,
      tokenUsdPrice: '1',
      usdToFiatRate: '1',
    );
    for (final text in [
      '',
      '-1',
      '1e3',
      'NaN',
      'Infinity',
      '1.001',
      '1,5',
      '12,34',
      '0,001',
      '1,,000',
      '.',
      'abc',
    ]) {
      expect(() => conversion.fiatToBaseUnits(text), throwsFormatException);
    }
    for (final price in ['0', '-1', 'NaN', 'Infinity']) {
      expect(
        () => SendAmountConversion(
          decimals: 8,
          tokenUsdPrice: price,
          usdToFiatRate: '1',
        ),
        throwsFormatException,
      );
    }
    for (final rate in ['0', '-1', 'NaN', 'Infinity']) {
      expect(
        () => SendAmountConversion(
          decimals: 8,
          tokenUsdPrice: '1',
          usdToFiatRate: rate,
        ),
        throwsFormatException,
      );
    }
    expect(conversion.fiatToBaseUnits('0'), BigInt.zero);
  });
}
