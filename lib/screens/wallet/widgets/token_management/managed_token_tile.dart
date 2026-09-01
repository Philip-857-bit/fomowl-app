import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../models/token.dart';
import '../../../../widgets/token_icon.dart';

/// Unified token tile with a toggle switch.
/// Used for wallet tokens, custom tokens, and search results — all in one list.
class ManagedTokenTile extends StatelessWidget {
  final Token token;
  final bool isEnabled;
  final bool isNative;
  final bool isProcessing;
  final ValueChanged<bool>? onToggleChanged;
  final int? chainId;
  final String? trustLabel;
  final bool isSuspicious;
  final bool isVerified;

  const ManagedTokenTile({
    super.key,
    required this.token,
    required this.isEnabled,
    this.isNative = false,
    this.isProcessing = false,
    this.onToggleChanged,
    this.chainId,
    this.trustLabel,
    this.isSuspicious = false,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final contractPreview = _contractPreview(token.contractAddress);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            isCertified: token.isCertified,
            size: 40,
            chainId: chainId,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      token.symbol,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    if (contractPreview != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        contractPreview,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ],
                ),
                if (trustLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    trustLabel!,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSuspicious
                          ? AppColors.accentRed
                          : isVerified
                          ? Colors.greenAccent
                          : Colors.white38,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentRed,
              ),
            )
          else
            CupertinoSwitch(
              value: isEnabled,
              activeTrackColor: AppColors.accentRed,
              onChanged: isNative ? null : onToggleChanged,
            ),
        ],
      ),
    );
  }

  String? _contractPreview(String? address) {
    if (address == null || address.isEmpty) return null;
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}
