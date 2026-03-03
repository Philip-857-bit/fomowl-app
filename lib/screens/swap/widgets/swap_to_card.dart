import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/token.dart';
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Swapping To:',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
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
                              color: AppColors.accentRed,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Calculating...',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        amountText.isEmpty ? '0' : amountText,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
              SwapTokenChip(token: token, onTap: onSelectToken, chainId: chainId),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${usdValue.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Row(
                children: [
                  Text(
                    '${balance.toStringAsFixed(4)} ${token?.symbol ?? ""}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4),
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
