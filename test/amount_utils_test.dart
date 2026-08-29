import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/amount_utils.dart';

void main() {
  group('AmountUtils', () {
    group('parseDecimalToBaseUnits', () {
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

      test('throws FormatException for empty or whitespace strings', () {
        expect(
          () => AmountUtils.parseDecimalToBaseUnits('', 18),
          throwsFormatException,
        );
        expect(
          () => AmountUtils.parseDecimalToBaseUnits('   ', 18),
          throwsFormatException,
        );
      });

      test('removes commas before parsing', () {
        expect(
          AmountUtils.parseDecimalToBaseUnits('1,234,567.89', 2),
          BigInt.parse('123456789'),
        );
      });

      test('trims whitespace before parsing', () {
        expect(
          AmountUtils.parseDecimalToBaseUnits('  123.45  ', 2),
          BigInt.parse('12345'),
        );
      });

      test('throws FormatException for invalid formats', () {
        expect(
          () => AmountUtils.parseDecimalToBaseUnits('abc', 18),
          throwsFormatException,
        );
        expect(
          () => AmountUtils.parseDecimalToBaseUnits('1.2.3', 18),
          throwsFormatException,
        );
        expect(
          () => AmountUtils.parseDecimalToBaseUnits('1.', 18),
          throwsFormatException,
        );
        expect(
          () => AmountUtils.parseDecimalToBaseUnits('-1', 18),
          throwsFormatException,
        );
      });

      test('parses integers correctly', () {
        expect(
          AmountUtils.parseDecimalToBaseUnits('1', 18),
          BigInt.parse('1000000000000000000'),
        );
      });

      test('parses zero correctly', () {
        expect(AmountUtils.parseDecimalToBaseUnits('0', 18), BigInt.zero);
        expect(AmountUtils.parseDecimalToBaseUnits('0.00', 18), BigInt.zero);
      });
    });

    group('formatBaseUnits', () {
      test('formats base units for display', () {
        expect(
          AmountUtils.formatBaseUnits(BigInt.parse('1234500000000000000'), 18),
          '1.2345',
        );
      });

      test('handles decimals <= 0', () {
        expect(AmountUtils.formatBaseUnits(BigInt.parse('123'), 0), '123');
        expect(AmountUtils.formatBaseUnits(BigInt.parse('123'), -2), '123');
      });

      test('handles negative values', () {
        expect(
          AmountUtils.formatBaseUnits(BigInt.parse('-1234500000000000000'), 18),
          '-1.2345',
        );
        expect(AmountUtils.formatBaseUnits(BigInt.parse('-123'), 0), '-123');
      });

      test('respects maxFractionDigits', () {
        expect(
          AmountUtils.formatBaseUnits(
            BigInt.parse('1234567800000000000'),
            18,
            maxFractionDigits: 4,
          ),
          '1.2345', // truncates the rest
        );
      });

      test('handles trimTrailingZeros flag', () {
        expect(
          AmountUtils.formatBaseUnits(
            BigInt.parse('1230000000000000000'),
            18,
            maxFractionDigits: 4,
            trimTrailingZeros: false,
          ),
          '1.2300',
        );
        expect(
          AmountUtils.formatBaseUnits(
            BigInt.parse('1000000000000000000'),
            18,
            maxFractionDigits: 4,
            trimTrailingZeros: false,
          ),
          '1.0000',
        );
        expect(
          AmountUtils.formatBaseUnits(
            BigInt.parse('1000000000000000000'),
            18,
            maxFractionDigits: 4,
            trimTrailingZeros: true,
          ),
          '1',
        );
      });

      test('formats zero correctly', () {
        expect(AmountUtils.formatBaseUnits(BigInt.zero, 18), '0');
        expect(
          AmountUtils.formatBaseUnits(
            BigInt.zero,
            18,
            maxFractionDigits: 2,
            trimTrailingZeros: false,
          ),
          '0.00',
        );
      });

      test('handles very small amounts correctly', () {
        expect(
          AmountUtils.formatBaseUnits(
            BigInt.parse('1'),
            18,
            maxFractionDigits: 18,
          ),
          '0.000000000000000001',
        );
      });
    });
  });
}
