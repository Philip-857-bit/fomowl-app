import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../models/token.dart';
import '../../../widgets/token_icon.dart';

class HomeTokenListItem extends StatelessWidget {
  const HomeTokenListItem({
    super.key,
    required this.token,
    required this.onTap,
    this.chainId,
  });

  final Token token;
  final VoidCallback onTap;
  final int? chainId;

  String get _displayName {
    final symbol = token.symbol.trim();
    final name = token.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return symbol.isEmpty ? 'Token' : symbol;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.topBarSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.canvasDark,
                shape: BoxShape.circle,
              ),
              child: TokenIcon(
                tokenSymbol: token.symbol,
                tokenAddress: token.contractAddress,
                tokenImageUrl: token.imageUrl,
                size: 36,
                backgroundColor: AppColors.canvasDark,
                chainId: chainId,
                isCertified: token.isCertified,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    token.formattedBalance,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  token.formattedValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      token.formattedChange,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: token.isPositiveChange
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    // PATCH: DEX-only resolved tokens show a compact source badge.
                    if (token.isDexPriced) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          // PATCH: Use the app's existing primary accent token.
                          color: AppColors.primaryAccent.withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DEX',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            // PATCH: Use the app's existing primary accent token.
                            color: AppColors.primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
