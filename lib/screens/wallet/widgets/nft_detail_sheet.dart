import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/nft_service.dart';
import 'nft_rarity_badge.dart';

class NftDetailSheet extends StatelessWidget {
  const NftDetailSheet({super.key, required this.nft});

  final NftAsset nft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nft.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      tooltip: l.closeLabel,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildArtwork(),
                      const SizedBox(height: 16),
                      if (nft.collection.trim().isNotEmpty)
                        Text(
                          nft.collection,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _NftMetaChip(label: nft.chainName),
                          _NftMetaChip(label: '${nft.count}x'),
                          if (nft.isCompressed)
                            const _NftMetaChip(label: 'Compressed NFT'),
                          if (nft.tokenId.isNotEmpty)
                            _NftMetaChip(label: '#${nft.tokenId}'),
                          if (nft.hasRarity)
                            NftRarityBadge(
                              label: nft.rarity,
                              rank: nft.rarityRank,
                              compact: false,
                            ),
                          if (nft.isProjectNft)
                            _NftMetaChip(
                              label: l.officialProjectNft,
                              highlighted: true,
                            ),
                        ],
                      ),
                      if (nft.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          nft.description.trim(),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _DetailSection(
                        label: l.networkLabel,
                        value: nft.chainName,
                      ),
                      if (nft.contractAddress.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _DetailSection(
                          label: l.contractAddressLabel,
                          value: nft.contractAddress,
                          onCopy: () =>
                              _copyValue(context, nft.contractAddress),
                        ),
                      ],
                      if (nft.contractAddress.trim().isNotEmpty &&
                          nft.tokenId.trim().isNotEmpty &&
                          nft.canUseStandardSendFlow) ...[
                        const SizedBox(height: 22),
                        _SendNftButton(nft: nft),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: nft.imageUrl.isNotEmpty
              ? Image.network(
                  nft.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  cacheHeight: 1080,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildArtworkFallback(),
                )
              : _buildArtworkFallback(),
        ),
      ),
    );
  }

  Widget _buildArtworkFallback() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: Colors.white.withValues(alpha: 0.18),
      ),
    );
  }

  Future<void> _copyValue(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
    );
  }
}

class _SendNftButton extends StatelessWidget {
  const _SendNftButton({required this.nft});

  final NftAsset nft;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushNamed('/send-nft', arguments: nft);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.accentRed,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentRed.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Send NFT',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  onPressed: onCopy,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  tooltip: l.copyToClipboard,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(left: 10),
                  splashRadius: 18,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NftMetaChip extends StatelessWidget {
  const _NftMetaChip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accentRed.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? AppColors.accentRed.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: highlighted ? AppColors.accentRed : Colors.white,
        ),
      ),
    );
  }
}
