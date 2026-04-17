import 'package:flutter/material.dart';

import '../../../models/token.dart';
import '../../../widgets/token_icon.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
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
            const SizedBox(width: 6),
            Text(
              symbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
