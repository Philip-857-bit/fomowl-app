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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                if (token != null)
                  TokenIcon(
                    tokenSymbol: token!.symbol,
                    tokenAddress: token!.contractAddress,
                    size: 38,
                  ),
                if (token != null) const SizedBox(width: 12),
                Text(
                  token?.symbol ?? 'Select',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Network: ${blockchain.activeChain.name}',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
