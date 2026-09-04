import 'package:flutter/widgets.dart';

/// Measures the rendered width of [text] laid out on a single line with [style].
double measureTextWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Returns the largest font size in [minFontSize, maxFontSize] at which
/// [amountText] (styled by [amountStyleFor]) still fits before a suffix symbol
/// ([suffixText] styled by [suffixStyle]) inside a box of width [boxWidth].
///
/// Used by the Send screen so a long amount (for example the full balance from
/// the 100% button, or an 18-decimal token) shrinks to fit instead of
/// overflowing into the token symbol suffix.
double fittedAmountFontSize({
  required String amountText,
  required TextStyle Function(double fontSize) amountStyleFor,
  required String suffixText,
  required TextStyle suffixStyle,
  required double boxWidth,
  double maxFontSize = 20,
  double minFontSize = 13,
  double horizontalPadding = 32,
  double gap = 12,
}) {
  final display = amountText.isEmpty ? '0' : amountText;
  final suffixWidth = suffixText.isEmpty
      ? 0.0
      : measureTextWidth(suffixText, suffixStyle);
  final available = boxWidth - horizontalPadding - suffixWidth - gap;
  if (available <= 0) return maxFontSize;

  final width = measureTextWidth(display, amountStyleFor(maxFontSize));
  if (width <= available) return maxFontSize;

  return (maxFontSize * available / width).clamp(minFontSize, maxFontSize);
}
