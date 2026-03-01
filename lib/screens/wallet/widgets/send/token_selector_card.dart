import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/token.dart';
import '../../../../services/blockchain_service.dart';
import '../../../../widgets/token_icon.dart';

class TokenSelectorCard extends StatelessWidget {
  final Token? token;
  final VoidCallback onTap;
  final BlockchainService blockchain;

  const TokenSelectorCard({
    super.key,
    required this.token,
    required this.onTap,
    required this.blockchain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT TOKEN & NETWORK',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                if (token != null)
                  TokenIcon(
                    tokenSymbol: token!.symbol,
                    tokenAddress: token!.contractAddress,
                    tokenImageUrl: token!.imageUrl,
                    size: 38,
                  ),
                if (token != null) const SizedBox(width: 12),
                Text(
                  token?.symbol ?? 'Select',
                  style: GoogleFonts.outfit(
                    fontSize: 31,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Network: ${blockchain.activeChain.name}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
