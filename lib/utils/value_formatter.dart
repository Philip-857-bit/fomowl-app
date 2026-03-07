import 'package:decimal/decimal.dart';

class ValueFormatter {
  ValueFormatter._();

  static final Decimal _thousand = Decimal.parse('1000');
  static final Decimal _million = Decimal.parse('1000000');
  static final Decimal _billion = Decimal.parse('1000000000');
  static final Decimal _trillion = Decimal.parse('1000000000000');

  static Decimal decimalFromNum(num? value) {
    if (value == null) return Decimal.zero;
    return Decimal.parse(value.toString());
  }

  static double doubleFromDecimal(Decimal value) {
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static String formatCompactTokenAmount(
    Decimal value, {
    required String symbol,
  }) {
    if (value >= _billion) {
      return '${_fixed(divide(value, _billion), 2)}B $symbol';
    }
    if (value >= _million) {
      return '${_fixed(divide(value, _million), 2)}M $symbol';
    }
    if (value >= _thousand) {
      return '${_fixed(divide(value, _thousand), 2)}K $symbol';
    }
    if (value >= Decimal.one) {
      return '${_fixed(value, 2)} $symbol';
    }
    return '${_fixed(value, 6)} $symbol';
  }

  static String formatUsdValue(Decimal value) {
    if (value >= _million) {
      return '\$${_fixed(divide(value, _million), 2)}M';
    }
    if (value >= _thousand) {
      return '\$${_fixed(divide(value, _thousand), 2)}K';
    }
    return '\$${_fixed(value, 2)}';
  }

  static String formatUsdPrice(Decimal value) {
    if (value <= Decimal.zero) return '\$0.00';
    if (value >= _thousand) return '\$${_fixed(value, 0)}';
    if (value >= Decimal.one) return '\$${_fixed(value, 2)}';
    return '\$${_fixed(value, 6)}';
  }

  static String formatCompactNumber(Decimal value) {
    if (value <= Decimal.zero) return '0';
    if (value >= _trillion) return '${_fixed(divide(value, _trillion), 2)}T';
    if (value >= _billion) return '${_fixed(divide(value, _billion), 2)}B';
    if (value >= _million) return '${_fixed(divide(value, _million), 2)}M';
    if (value >= _thousand) return '${_fixed(divide(value, _thousand), 2)}K';
    return _fixed(value, 0);
  }

  static Decimal divide(Decimal left, Decimal right) {
    if (right == Decimal.zero) return Decimal.zero;
    final leftDouble = double.tryParse(left.toString()) ?? 0.0;
    final rightDouble = double.tryParse(right.toString()) ?? 1.0;
    return Decimal.parse((leftDouble / rightDouble).toString());
  }

  static String formatCurrencyWithGrouping(Decimal value) {
    final fixed = _fixed(value, 2);
    final parts = fixed.split('.');
    final whole = _groupThousands(parts.first);
    return parts.length == 1 ? '\$$whole' : '\$$whole.${parts[1]}';
  }

  static String _fixed(Decimal value, int fractionDigits) {
    var text = value.toString();
    final negative = text.startsWith('-');
    if (negative) {
      text = text.substring(1);
    }

    final parts = text.split('.');
    final whole = parts.first;
    var fraction = parts.length > 1 ? parts[1] : '';

    if (fractionDigits == 0) {
      return '${negative ? '-' : ''}$whole';
    }

    if (fraction.length > fractionDigits) {
      fraction = fraction.substring(0, fractionDigits);
    } else {
      fraction = fraction.padRight(fractionDigits, '0');
    }

    return '${negative ? '-' : ''}$whole.$fraction';
  }

  static String _groupThousands(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final indexFromRight = input.length - i;
      buffer.write(input[i]);
      if (indexFromRight > 1 && indexFromRight % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}
