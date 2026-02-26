import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../widgets/token_icon.dart';

class TokensSection extends StatelessWidget {
  final List<Token> tokens;
  final bool isLoading;
  final AppLocalizations localization;
  final VoidCallback onManageTokens;
  final VoidCallback onOpenNfts;
  final bool Function(Token token) isTokenHidden;
  final void Function(Token token) onSelectToken;

  const TokensSection({
    super.key,
    required this.tokens,
    required this.isLoading,
    required this.localization,
    required this.onManageTokens,
    required this.onOpenNfts,
    required this.isTokenHidden,
    required this.onSelectToken,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTokens = tokens.where((token) => !isTokenHidden(token)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                localization.tokens,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentRed,
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onOpenNfts,
                child: Text(
                  localization.nfts,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.tune, color: Colors.white.withValues(alpha: 0.5), size: 20),
                onPressed: onManageTokens,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.accentRed),
                  const SizedBox(height: 16),
                  Text(localization.loadingBalances, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54)),
                ],
              ),
            ),
          )
        else if (visibleTokens.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    localization.noTokensYet,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localization.depositTokens,
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...visibleTokens.map(
            (token) => _TokenListItem(
              token: token,
              onTap: () => onSelectToken(token),
            ),
          ),
      ],
    );
  }
}

class _TokenListItem extends StatelessWidget {
  final Token token;
  final VoidCallback onTap;

  const _TokenListItem({required this.token, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            TokenIcon(tokenSymbol: token.symbol, tokenAddress: token.contractAddress, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    token.formattedBalance,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  token.formattedValue,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  token.formattedChange,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: token.isPositiveChange ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
