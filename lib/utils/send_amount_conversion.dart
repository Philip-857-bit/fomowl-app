import 'package:decimal/decimal.dart';

import 'amount_utils.dart';

/// Exact conversion of a display-currency amount into token base units.
/// Prices are estimates; rounding always reduces the requested token debit.
class SendAmountConversion {
  SendAmountConversion({
    required this.decimals,
    required String tokenUsdPrice,
    required String usdToFiatRate,
    String tokenBalance = '0',
    String tokenValueUsd = '0',
  }) {
    if (decimals < 0 || decimals > 255) {
      throw const FormatException('Unsupported token precision.');
    }
    var price = _fraction(tokenUsdPrice);
    if (price.$1 == BigInt.zero) {
      final balance = _fraction(tokenBalance);
      final value = _fraction(tokenValueUsd);
      if (balance.$1 <= BigInt.zero || value.$1 <= BigInt.zero) {
        throw const FormatException('Token price is unavailable.');
      }
      price = (value.$1 * balance.$2, value.$2 * balance.$1);
    }
    final rate = _fraction(usdToFiatRate);
    if (price.$1 <= BigInt.zero || rate.$1 <= BigInt.zero) {
      throw const FormatException('Conversion rate is unavailable.');
    }
    _priceNumerator = price.$1 * rate.$1;
    _priceDenominator = price.$2 * rate.$2;
  }

  final int decimals;
  late final BigInt _priceNumerator;
  late final BigInt _priceDenominator;

  static (BigInt, BigInt) _fraction(String raw) {
    final normalized = Decimal.parse(raw).toString();
    if (normalized.startsWith('-')) {
      throw const FormatException('Negative conversion value.');
    }
    final parts = normalized.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    return (
      BigInt.parse('${parts[0]}$fraction'),
      BigInt.from(10).pow(fraction.length),
    );
  }

  BigInt fiatToBaseUnits(String raw) {
    final entered = raw.trim();
    // Accept standard grouping, never reinterpret a decimal comma as a larger
    // amount (for example, "1,5" must not become "15").
    if (entered.length > 160 ||
        !RegExp(
          r'^(?:\d+|[1-9]\d{0,2}(?:,\d{3})+)(?:\.\d{1,2})?$',
        ).hasMatch(entered)) {
      throw const FormatException(
        'Enter an amount with at most 2 decimal places.',
      );
    }
    final fiat = _fraction(entered.replaceAll(',', ''));
    return (fiat.$1 * _priceDenominator * BigInt.from(10).pow(decimals)) ~/
        (fiat.$2 * _priceNumerator);
  }

  /// Full token precision is retained independently of the two-decimal display.
  String baseUnitsToFiat(BigInt baseUnits) {
    if (baseUnits.isNegative) {
      throw const FormatException('Negative token amount.');
    }
    final cents =
        (baseUnits * _priceNumerator * BigInt.from(100)) ~/
        (BigInt.from(10).pow(decimals) * _priceDenominator);
    return AmountUtils.formatBaseUnits(
      cents,
      2,
      maxFractionDigits: 2,
      trimTrailingZeros: false,
    );
  }
}
