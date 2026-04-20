import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/token.dart';
import '../../../widgets/token_icon.dart';
import 'swap_figma_icons.dart';

class SwapTokenChip extends StatelessWidget {
  final Token? token;
  final VoidCallback onTap;
  final int? chainId;

  const SwapTokenChip({
    super.key,
    required this.token,
    required this.onTap,
    this.chainId,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = token?.symbol ?? '--';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x265D3F3D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: TokenIcon(
                tokenSymbol: symbol,
                tokenAddress: token?.contractAddress,
                tokenImageUrl: token?.imageUrl,
                size: 24,
                chainId: chainId,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              symbol,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFE2E2E2),
              ),
            ),
            const SizedBox(width: 8),
            const FigmaDropdownIcon(width: 6, color: Color(0xFFC8C6C5)),
          ],
        ),
      ),
    );
  }
}
