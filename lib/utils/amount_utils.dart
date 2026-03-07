import 'dart:math';

class AmountUtils {
  AmountUtils._();

  static BigInt parseDecimalToBaseUnits(String rawAmount, int decimals) {
    final sanitized = rawAmount.trim().replaceAll(',', '');
    if (sanitized.isEmpty) {
      throw const FormatException('Amount is required.');
    }

    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(sanitized);
    if (match == null) {
      throw const FormatException('Invalid amount format.');
    }

    final integerPart = match.group(1) ?? '0';
    final fractionPart = match.group(2) ?? '';
    if (fractionPart.length > decimals) {
      throw FormatException('Amount supports up to $decimals decimals.');
    }

    final paddedFraction = fractionPart.padRight(decimals, '0');
    final combined = '$integerPart$paddedFraction';
    return BigInt.parse(combined.isEmpty ? '0' : combined);
  }

  static String formatBaseUnits(
    BigInt value,
    int decimals, {
    int maxFractionDigits = 6,
    bool trimTrailingZeros = true,
  }) {
    final negative = value.isNegative;
    final digits = value.abs().toString();

    if (decimals <= 0) {
      return '${negative ? '-' : ''}$digits';
    }

    final padded = digits.padLeft(decimals + 1, '0');
    final integerPart = padded.substring(0, padded.length - decimals);
    var fractionPart = padded.substring(padded.length - decimals);

    final limit = min(maxFractionDigits, fractionPart.length);
    fractionPart = fractionPart.substring(0, limit);
    if (trimTrailingZeros) {
      fractionPart = fractionPart.replaceFirst(RegExp(r'0+$'), '');
    }

    if (fractionPart.isEmpty) {
      return '${negative ? '-' : ''}$integerPart';
    }
    return '${negative ? '-' : ''}$integerPart.$fractionPart';
  }
}
