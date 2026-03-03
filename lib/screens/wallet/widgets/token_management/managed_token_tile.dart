import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/token.dart';
import '../../../../widgets/token_icon.dart';

class ManagedTokenTile extends StatelessWidget {
  final Token token;
  final bool isVisible;
  final ValueChanged<bool> onVisibilityChanged;
  final int? chainId;

  const ManagedTokenTile({
    super.key,
    required this.token,
    required this.isVisible,
    required this.onVisibilityChanged,
    this.chainId,
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
            chainId: chainId,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  token.symbol,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Toggle visibility for ${token.name}',
            checked: isVisible,
            onTap: () => onVisibilityChanged(!isVisible),
            child: Switch(
              value: isVisible,
              onChanged: onVisibilityChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.transparent,
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: Colors.transparent,
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.white24;
              }),
            ),
          ),
        ],
      ),
    );
  }
}
