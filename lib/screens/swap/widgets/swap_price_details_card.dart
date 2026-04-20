import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final feePercent = platformFeePercent > 0
        ? '${platformFeePercent.toStringAsFixed(1)}%'
        : '1%';
    return Column(
      children: [
        _buildDetailRow('Price', priceText, isPrice: true),
        const SizedBox(height: 12),
        _buildDetailRow('Total Tax', '0.5%'),
        const SizedBox(height: 12),
        _buildDetailRow('Fee', feePercent),
        const SizedBox(height: 12),
        _buildDetailRow('To Receive', receiveText),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrice = false}) {
    final priceRow = isPrice && value.contains(priceSeparator);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA1A1AA),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
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
              ),
            ),
            TextSpan(
              text: parts[1].trim(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B1A1A),
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
      ),
    );
  }
}
