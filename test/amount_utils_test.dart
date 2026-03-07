import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/amount_utils.dart';

void main() {
  group('AmountUtils', () {
    test('parses decimal amount to base units deterministically', () {
      expect(
        AmountUtils.parseDecimalToBaseUnits('0.123456', 18),
        BigInt.parse('123456000000000000'),
      );
    });

    test('rejects too many decimal places', () {
      expect(
        () => AmountUtils.parseDecimalToBaseUnits('0.1234567', 6),
        throwsFormatException,
      );
    });

    test('formats base units for display', () {
      expect(
        AmountUtils.formatBaseUnits(BigInt.parse('1234500000000000000'), 18),
        '1.2345',
      );
    });
  });
}
