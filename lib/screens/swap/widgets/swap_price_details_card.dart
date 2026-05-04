import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/value_formatter.dart';

class SwapPriceDetailsCard extends StatelessWidget {
  final String priceText;
  final double platformFeePercent;
  final double platformFeeUsd;
  final double feeAmountUsd;
  final double feeAmountNative;
  final String nativeFeeSymbol;
  final String receiveText;
  final String priceSeparator;
  final double swapAmountUsd;
  final bool gaslessFeeCovered;

  /// Native token price in USD from the frontend CoinGecko cache.
  /// Used to compute network fee in USD when the backend returns 0.
  final double nativePriceUsd;

  const SwapPriceDetailsCard({
    super.key,
    required this.priceText,
    required this.platformFeePercent,
    required this.platformFeeUsd,
    required this.feeAmountUsd,
    required this.feeAmountNative,
    required this.nativeFeeSymbol,
    required this.receiveText,
    this.priceSeparator = '->',
    this.swapAmountUsd = 0.0,
    this.nativePriceUsd = 0.0,
    this.gaslessFeeCovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final feeText = _buildFeeText();
    final resolvedPlatformFeePercent = _resolvedPlatformFeePercent();
    final platformFeeText = resolvedPlatformFeePercent > 0
        ? _formatPercent(resolvedPlatformFeePercent)
        : '0';
    final estTotalText = receiveText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTION DETAILS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: const Color(0xFF8894A0),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
          decoration: BoxDecoration(
            color: const Color(0xFF151C24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A333D)),
          ),
          child: Column(
            children: [
              _buildDetailRow('Rate', priceText, isPrice: true),
              const SizedBox(height: 14),
              _buildDetailRowWithInfo('Total tax', feeText),
              const SizedBox(height: 14),
              _buildDetailRowWithInfo('Platform Fee', platformFeeText),
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFF2B3139)),
              const SizedBox(height: 14),
              _buildDetailRow('Est. Total', estTotalText, isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  double _resolvedPlatformFeePercent() {
    if (platformFeePercent > 0) {
      return platformFeePercent;
    }
    if (swapAmountUsd > 0 && platformFeeUsd > 0) {
      return (platformFeeUsd / swapAmountUsd) * 100;
    }
    return 0.0;
  }

  String _formatPercent(double value) {
    if (value <= 0) return '0%';
    if (value < 0.1) return '<0.1%';
    return '${value.toStringAsFixed(1)}%';
  }

  String _formatApproxFiat(double value) {
    if (value <= 0) return '';
    final converted = ValueFormatter.convertFromUsdDecimal(
      ValueFormatter.decimalFromNum(value),
    );
    final convertedValue = ValueFormatter.doubleFromDecimal(converted);
    final prefix = ValueFormatter.currencyPrefix;
    if (convertedValue < 0.1) return '<${prefix}0.1';
    return '~$prefix${convertedValue.toStringAsFixed(1)}';
  }

  String _formatApproxNative(double value) {
    if (value <= 0) return '';
    if (value < 0.1) return '<0.1 $nativeFeeSymbol';
    return '~${value.toStringAsFixed(1)} $nativeFeeSymbol';
  }

  String _buildFeeText() {
    final feeNativeText = _formatApproxNative(feeAmountNative);
    final feeUsdText = _formatApproxFiat(feeAmountUsd);

    if (feeNativeText.isEmpty && feeUsdText.isEmpty) {
      return '0';
    }
    if (feeNativeText.isNotEmpty && feeUsdText.isNotEmpty) {
      return '$feeNativeText ($feeUsdText)';
    }
    return feeNativeText.isNotEmpty ? feeNativeText : feeUsdText;
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isPrice = false,
    bool isBold = false,
  }) {
    final priceRow = isPrice && value.contains(priceSeparator);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w400 : FontWeight.w400,
              color: const Color(0xFF848E9C),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerRight,
            child: priceRow
                ? _buildPriceText(value)
                : Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                      color: const Color(0xFFEAECEF),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRowWithInfo(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF848E9C),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.info_outline_rounded,
          size: 12,
          color: Color(0xFF848E9C),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFEAECEF),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceText(String text) {
    final parts = text.split(priceSeparator);
    if (parts.length == 2) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${parts[0]}$priceSeparator ',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFFFFF),
                height: 1.43,
              ),
            ),
            TextSpan(
              text: parts[1].trim(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B1A1A),
                height: 1.43,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      );
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFFFFFFF),
        height: 1.43,
      ),
    );
  }
}
