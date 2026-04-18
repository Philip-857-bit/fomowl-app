import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../services/nft_service.dart';
import '../home_portfolio_data.dart';
import 'home_token_list_item.dart';
import 'portfolio_tab_content.dart';

enum HomeAssetTab { tokens, portfolio, nfts }

class TokensSection extends StatefulWidget {
  final List<Token> tokens;
  final List<HomePortfolioSection> portfolioSections;
  final bool isLoading;
  final bool isLoadingPortfolio;
  final bool isLoadingNfts;
  final List<NftAsset> nftPreview;
  final bool hasMoreNfts;
  final AppLocalizations localization;
  final VoidCallback onManageTokens;
  final VoidCallback onOpenNfts;
  final bool Function(Token token) isTokenHidden;
  final void Function(Token token) onSelectToken;
  final int? chainId;
  final HomeAssetTab initialTab;
  final ValueChanged<HomeAssetTab>? onTabChanged;

  const TokensSection({
    super.key,
    required this.tokens,
    required this.portfolioSections,
    required this.isLoading,
    required this.isLoadingPortfolio,
    required this.isLoadingNfts,
    required this.nftPreview,
    required this.hasMoreNfts,
    required this.localization,
    required this.onManageTokens,
    required this.onOpenNfts,
    required this.isTokenHidden,
    required this.onSelectToken,
    this.chainId,
    this.initialTab = HomeAssetTab.portfolio,
    this.onTabChanged,
  });

  @override
  State<TokensSection> createState() => _TokensSectionState();
}

class _TokensSectionState extends State<TokensSection> {
  late HomeAssetTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  void _setTab(HomeAssetTab tab) {
    if (_selectedTab == tab) {
      return;
    }
    setState(() => _selectedTab = tab);
    widget.onTabChanged?.call(tab);
  }

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _AssetTabChip(
                      label: widget.localization.tokens,
                      selected: _selectedTab == HomeAssetTab.tokens,
                      onTap: () => _setTab(HomeAssetTab.tokens),
                    ),
                    const SizedBox(width: 20),
                    _AssetTabChip(
                      label: widget.localization.portfolio,
                      selected: _selectedTab == HomeAssetTab.portfolio,
                      onTap: () => _setTab(HomeAssetTab.portfolio),
                    ),
                    const SizedBox(width: 20),
                    _AssetTabChip(
                      label: widget.localization.nfts,
                      selected: _selectedTab == HomeAssetTab.nfts,
                      onTap: () => _setTab(HomeAssetTab.nfts),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedTab == HomeAssetTab.tokens)
                _AssetToolbarButton(
                  icon: Icons.tune_rounded,
                  onTap: widget.onManageTokens,
                )
              else if (_selectedTab == HomeAssetTab.nfts && widget.hasMoreNfts)
                _AssetTextButton(
                  label: widget.localization.viewAll,
                  onTap: widget.onOpenNfts,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedTab == HomeAssetTab.tokens)
          ..._buildTokensContent(visibleTokens)
        else if (_selectedTab == HomeAssetTab.portfolio)
          PortfolioTabContent(
            sections: widget.portfolioSections,
            isLoading: widget.isLoadingPortfolio,
            localization: widget.localization,
            onSelectToken: widget.onSelectToken,
          )
        else
          _buildNftsContent(),
      ],
    );
  }

  List<Widget> _buildTokensContent(List<Token> visibleTokens) {
    if (widget.isLoading && visibleTokens.isEmpty) {
      return _buildSkeletonList();
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
          (token) => HomeTokenListItem(
            token: token,
            onTap: () => widget.onSelectToken(token),
            chainId: widget.chainId,
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

  List<Widget> _buildSkeletonList() {
    return List.generate(
      4,
      (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 30,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
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

class _AssetTabChip extends StatelessWidget {
  const _AssetTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.accentRed
                : Colors.white.withValues(alpha: 0.62),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _AssetToolbarButton extends StatelessWidget {
  const _AssetToolbarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.75),
          size: 20,
        ),
      ),
    );
  }
}

class _AssetTextButton extends StatelessWidget {
  const _AssetTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            color: AppColors.accentRed,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
