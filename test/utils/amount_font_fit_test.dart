import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/screens/wallet/widgets/send/amount_font_fit.dart';

void main() {
  TextStyle amountStyleFor(double fontSize) =>
      TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700);
  const suffixStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

  const maxFontSize = 20.0;
  const minFontSize = 13.0;
  const boxWidth = 330.0;

  double sizeFor(String amount, String suffix, {double width = boxWidth}) {
    return fittedAmountFontSize(
      amountText: amount,
      amountStyleFor: amountStyleFor,
      suffixText: suffix,
      suffixStyle: suffixStyle,
      boxWidth: width,
      maxFontSize: maxFontSize,
      minFontSize: minFontSize,
    );
  }

  // The result must never overflow into the suffix, unless it was clamped to the
  // minimum size (in which case the field scrolls instead).
  void expectFitsOrClamped(String amount, String suffix, double size) {
    if (size <= minFontSize) return; // clamped: scrolling handles the rest
    final amountWidth = measureTextWidth(amount, amountStyleFor(size));
    final suffixWidth = measureTextWidth(suffix, suffixStyle);
    final available = boxWidth - 32 - suffixWidth - 12;
    expect(amountWidth, lessThanOrEqualTo(available + 0.5));
  }

  group('fittedAmountFontSize', () {
    test('keeps the maximum size for a short amount that fits', () {
      expect(sizeFor('5', 'USDT'), maxFontSize);
    });

    test('shrinks the reported full-balance amount so it no longer overflows '
        'into the USDT suffix', () {
      const amount = '31.6984344785497';
      final size = sizeFor(amount, 'USDT');
      expect(size, lessThan(maxFontSize));
      expect(size, greaterThanOrEqualTo(minFontSize));
      expectFitsOrClamped(amount, 'USDT', size);
    });

    test('shrinks more for a longer amount than a shorter one', () {
      final shorter = sizeFor('31.69', 'USDT');
      final longer = sizeFor('31.6984344785497', 'USDT');
      expect(longer, lessThanOrEqualTo(shorter));
    });

    test('stays within [min, max] for an 18-decimal amount', () {
      final size = sizeFor('0.123456789012345678', 'SHIB');
      expect(size, lessThanOrEqualTo(maxFontSize));
      expect(size, greaterThanOrEqualTo(minFontSize));
      expectFitsOrClamped('0.123456789012345678', 'SHIB', size);
    });

    test('never shrinks below the minimum font size', () {
      final size = sizeFor(
        '123456789012345678901234567890',
        'TOKEN',
        width: 200,
      );
      expect(size, greaterThanOrEqualTo(minFontSize));
    });
  });
}
