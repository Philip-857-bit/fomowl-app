import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../widgets/amount_input_mode_toggle.dart';

class AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final double availableBalance;
  final String tokenSymbol;
  final VoidCallback onMaxTap;
  final String fiatValueText;
  final String rateText;
  final AmountInputMode inputMode;
  final VoidCallback? onToggleInputMode;
  final String inputSuffixLabel;
  final String equivalentText;

  const AmountInputField({
    super.key,
    required this.controller,
    required this.availableBalance,
    required this.tokenSymbol,
    required this.onMaxTap,
    this.fiatValueText = '',
    this.rateText = '',
    this.inputMode = AmountInputMode.token,
    this.onToggleInputMode,
    this.inputSuffixLabel = '',
    this.equivalentText = '',
  });

  @override
  Widget build(BuildContext context) {
    final suffix = inputSuffixLabel.isNotEmpty ? inputSuffixLabel : tokenSymbol;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AMOUNT',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleInputMode != null) ...[
                  AmountInputModeToggle(
                    mode: inputMode,
                    tokenSymbol: tokenSymbol,
                    onToggle: onToggleInputMode!,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  'Available: ${availableBalance.toStringAsFixed(2)} $tokenSymbol',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: GoogleFonts.outfit(
                fontSize: 22,
                color: Colors.white.withValues(alpha: 0.3),
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suffix,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onMaxTap,
                    child: Text(
                      'MAX',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
        if (equivalentText.isNotEmpty ||
            fiatValueText.isNotEmpty ||
            rateText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  equivalentText.isNotEmpty ? equivalentText : fiatValueText,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (rateText.isNotEmpty)
                Flexible(
                  child: Text(
                    rateText,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
