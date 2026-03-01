import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/token.dart';
import '../../../../widgets/token_icon.dart';

class ManagedTokenTile extends StatelessWidget {
  final Token token;
  final bool isVisible;
  final ValueChanged<bool> onVisibilityChanged;

  const ManagedTokenTile({
    super.key,
    required this.token,
    required this.isVisible,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          TokenIcon(
            tokenSymbol: token.symbol,
            tokenAddress: token.contractAddress,
            tokenImageUrl: token.imageUrl,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  token.symbol,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isVisible,
            onChanged: onVisibilityChanged,
            activeTrackColor: AppColors.accentRed.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
