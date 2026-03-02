import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../services/nft_service.dart';
import '../../../widgets/token_icon.dart';

enum _AssetTab { tokens, nfts }

class TokensSection extends StatefulWidget {
  final List<Token> tokens;
  final bool isLoading;
  final bool isLoadingNfts;
  final List<NftAsset> nftPreview;
  final bool hasMoreNfts;
  final AppLocalizations localization;
  final VoidCallback onManageTokens;
  final VoidCallback onOpenNfts;
  final bool Function(Token token) isTokenHidden;
  final void Function(Token token) onSelectToken;

  const TokensSection({
    super.key,
    required this.tokens,
    required this.isLoading,
    required this.isLoadingNfts,
    required this.nftPreview,
    required this.hasMoreNfts,
    required this.localization,
    required this.onManageTokens,
    required this.onOpenNfts,
    required this.isTokenHidden,
    required this.onSelectToken,
  });

  @override
  State<TokensSection> createState() => _TokensSectionState();
}

class _TokensSectionState extends State<TokensSection> {
  _AssetTab _selectedTab = _AssetTab.tokens;

  @override
  Widget build(BuildContext context) {
    final visibleTokens = widget.tokens
        .where((token) => !widget.isTokenHidden(token))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedTab = _AssetTab.tokens),
                child: Text(
                  widget.localization.tokens,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: _selectedTab == _AssetTab.tokens
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedTab == _AssetTab.tokens
                        ? AppColors.accentRed
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = _AssetTab.nfts),
                child: Text(
                  widget.localization.nfts,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: _selectedTab == _AssetTab.nfts
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedTab == _AssetTab.nfts
                        ? AppColors.accentRed
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Spacer(),
              if (_selectedTab == _AssetTab.tokens)
                IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: widget.onManageTokens,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                )
              else if (widget.hasMoreNfts)
                GestureDetector(
                  onTap: widget.onOpenNfts,
                  child: Text(
                    widget.localization.viewAll,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.accentRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedTab == _AssetTab.tokens)
          ..._buildTokensContent(visibleTokens)
        else
          _buildNftsContent(),
      ],
    );
  }

  List<Widget> _buildTokensContent(List<Token> visibleTokens) {
    if (widget.isLoading) {
      return [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(color: AppColors.accentRed),
                const SizedBox(height: 16),
                Text(
                  widget.localization.loadingBalances,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (visibleTokens.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 60,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.localization.noTokensYet,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.localization.depositTokens,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return visibleTokens
        .map(
          (token) => _TokenListItem(
            token: token,
            onTap: () => widget.onSelectToken(token),
          ),
        )
        .toList();
  }

  Widget _buildNftsContent() {
    if (widget.isLoadingNfts) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: LinearProgressIndicator(
          minHeight: 3,
          color: AppColors.accentRed,
          backgroundColor: Color(0x22111111),
        ),
      );
    }

    if (widget.nftPreview.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.collections_outlined,
                size: 60,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              Text(
                widget.localization.noNftsFound,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.localization.nftPreviewDescription,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _NftPreviewStrip(
          nfts: widget.nftPreview,
          hasMoreNfts: widget.hasMoreNfts,
          onOpenNfts: widget.onOpenNfts,
          localization: widget.localization,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _NftPreviewStrip extends StatelessWidget {
  final List<NftAsset> nfts;
  final bool hasMoreNfts;
  final VoidCallback onOpenNfts;
  final AppLocalizations localization;

  const _NftPreviewStrip({
    required this.nfts,
    required this.hasMoreNfts,
    required this.onOpenNfts,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  localization.nftPreview,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (hasMoreNfts)
                  GestureDetector(
                    onTap: onOpenNfts,
                    child: Text(
                      localization.viewAll,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.accentRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: nfts.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final nft = nfts[index];
                return Container(
                  width: 98,
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: nft.imageUrl.isNotEmpty
                              ? Image.network(
                                  nft.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: double.infinity,
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 24,
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                )
                              : Container(
                                  width: double.infinity,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: Icon(
                                    Icons.image,
                                    size: 24,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Text(
                          nft.name,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
            TokenIcon(
              tokenSymbol: token.symbol,
              tokenAddress: token.contractAddress,
              tokenImageUrl: token.imageUrl,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    token.formattedBalance,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
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
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  token.formattedChange,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: token.isPositiveChange
                        ? AppColors.success
                        : AppColors.error,
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
