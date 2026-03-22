import 'package:decimal/decimal.dart';

class ValueFormatter {
  ValueFormatter._();

  static final Decimal _thousand = Decimal.parse('1000');
  static final Decimal _million = Decimal.parse('1000000');
  static final Decimal _billion = Decimal.parse('1000000000');
  static final Decimal _trillion = Decimal.parse('1000000000000');
  static String _currencyCode = 'USD';

  static const Map<String, String> _currencySymbols = {
    'USD': r'$',
    'EUR': 'EUR ',
    'GBP': 'GBP ',
    'NGN': 'NGN ',
  };

  static Map<String, Decimal> _usdConversionRates = {'USD': Decimal.one};

  static void setCurrencyCode(String code) {
    final normalized = code.trim().toUpperCase();
    _currencyCode = _currencySymbols.containsKey(normalized)
        ? normalized
        : 'USD';
  }

  static void updateUsdConversionRates(Map<String, double> rates) {
    final nextRates = <String, Decimal>{'USD': Decimal.one};
    for (final entry in rates.entries) {
      final normalized = entry.key.trim().toUpperCase();
      if (normalized.isEmpty || entry.value <= 0) {
        continue;
      }
      nextRates[normalized] = Decimal.parse(entry.value.toString());
    }
    _usdConversionRates = nextRates;
  }

  static String get currencyCode => _currencyCode;

  static String get _currencySymbol =>
      _currencySymbols[_currencyCode] ?? _currencySymbols['USD']!;

  static Decimal _convertFromUsd(Decimal value) {
    final rate = _usdConversionRates[_currencyCode];
    if (_currencyCode != 'USD' && rate == null) {
      return value;
    }
    final effectiveRate = rate ?? Decimal.one;
    return value * effectiveRate;
  }

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
    if (value >= _trillion) {
      return '${_fixed(divide(value, _trillion), 2)}T $symbol';
    }
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
    final converted = _convertFromUsd(value);
    if (converted >= _trillion) {
      return '$_currencySymbol${_fixed(divide(converted, _trillion), 2)}T';
    }
    if (converted >= _billion) {
      return '$_currencySymbol${_fixed(divide(converted, _billion), 2)}B';
    }
    if (converted >= _million) {
      return '$_currencySymbol${_fixed(divide(converted, _million), 2)}M';
    }
    if (converted >= _thousand) {
      return '$_currencySymbol${_fixed(divide(converted, _thousand), 2)}K';
    }
    return '$_currencySymbol${_fixed(converted, 2)}';
  }

  static String formatUsdValueOrLessThanCent(Decimal value) {
    final converted = _convertFromUsd(value);
    if (converted > Decimal.zero && converted < Decimal.parse('0.01')) {
      return '<${_currencySymbol}0.01';
    }
    return formatUsdValue(value);
  }

  static String formatUsdPrice(Decimal value) {
    final converted = _convertFromUsd(value);
    if (converted <= Decimal.zero) return '${_currencySymbol}0.00';
    if (converted >= _thousand) {
      return '$_currencySymbol${_fixed(converted, 0)}';
    }
    if (converted >= Decimal.one) {
      return '$_currencySymbol${_fixed(converted, 2)}';
    }
    return '$_currencySymbol${_fixed(converted, 6)}';
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
    final fixed = _fixed(_convertFromUsd(value), 2);
    final parts = fixed.split('.');
    final whole = _groupThousands(parts.first);
    return parts.length == 1
        ? '$_currencySymbol$whole'
        : '$_currencySymbol$whole.${parts[1]}';
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
