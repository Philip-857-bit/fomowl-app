import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import 'swap_token_chip.dart';

class SwapToCard extends StatelessWidget {
  final Token? token;
  final String amountText;
  final double usdValue;
  final double balance;
  final bool isCalculating;
  final VoidCallback onSelectToken;
  final int? chainId;

  const SwapToCard({
    super.key,
    required this.token,
    required this.amountText,
    required this.usdValue,
    required this.balance,
    required this.isCalculating,
    required this.onSelectToken,
    this.chainId,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.swapToLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFA1A1AA),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: isCalculating
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Color(0xFFEA2A33),
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.calculatingLabel,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        amountText.isEmpty ? '0' : amountText,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
              ),
              SwapTokenChip(
                token: token,
                onTap: onSelectToken,
                chainId: chainId,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ValueFormatter.formatCurrencyWithGrouping(
                  ValueFormatter.decimalFromNum(usdValue),
                ),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF71717A),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF73D3F0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${balance.toStringAsFixed(4)} ${token?.symbol ?? ""}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
