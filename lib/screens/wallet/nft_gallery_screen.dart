import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../services/nft_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';
import 'widgets/nft_detail_sheet.dart';
import 'widgets/nft_rarity_badge.dart';

/// NFT Gallery Screen
/// Shows NFTs owned by the wallet across supported chains.
class NftGalleryScreen extends StatefulWidget {
  const NftGalleryScreen({super.key});

  @override
  State<NftGalleryScreen> createState() => _NftGalleryScreenState();
}

class _NftGalleryScreenState extends State<NftGalleryScreen> {
  final WalletService _walletService = WalletService();
  final NftService _nftService = NftService();

  List<NftAsset> _nfts = [];
  String? _selectedCollectionKey;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final argument = ModalRoute.of(context)?.settings.arguments;
        _selectedCollectionKey = argument is String ? argument : null;
        _fetchNfts();
      }
    });
  }

  Future<void> _fetchNfts() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final address = await _walletService.getCurrentWalletAddress();
      final solanaAddress = await _walletService.getWalletAddressForFamily(
        ChainFamily.solana,
      );
      final evmAddress =
          address != null &&
              RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address.trim())
          ? address.trim()
          : '';

      if (evmAddress.isEmpty &&
          (solanaAddress == null || solanaAddress.isEmpty)) {
        setState(() {
          _isLoading = false;
          _errorMessage = l.noActiveWalletFound;
        });
        return;
      }

      final activeChain = blockchain.activeChain;
      final orderedChains = [
        activeChain,
        ...blockchain.allChains.where(
          (chain) => chain.chainId != activeChain.chainId,
        ),
      ];
      final owned = await _nftService.fetchOwnedNftsAcrossChains(
        chains: orderedChains,
        walletAddress: evmAddress,
        solanaWalletAddress: solanaAddress ?? '',
      );

      if (!mounted) return;
      setState(() {
        _nfts = owned;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppErrorUtils.userMessage(
          e,
          fallback: l.failedToLoadNftsTitle,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedCollection = _selectedCollection();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (_selectedCollectionKey != null) {
                        setState(() => _selectedCollectionKey = null);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Text(
                    selectedCollection?.name ?? l.nftCollection,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l.allChains,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.accentRed,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l.nftGalleryScanning,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                  ? _buildErrorState()
                  : _nfts.isEmpty
                  ? _buildEmptyState(l)
                  : _selectedCollectionKey == null
                  ? _buildCollectionGrid()
                  : _buildNftGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.collections_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.noNftsYet,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.nftGalleryEmptyDescription,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _fetchNfts,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: AppColors.accentRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.refresh,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l.failedToLoadNftsTitle,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _fetchNfts,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l.tryAgain,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNftGrid() {
    final nfts = _nfts
        .where((nft) => _collectionKeyFor(nft) == _selectedCollectionKey)
        .toList();
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: nfts.length,
      itemBuilder: (context, index) {
        final nft = nfts[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showNftDetails(nft),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: nft.imageUrl.isNotEmpty
                                ? Image.network(
                                    nft.imageUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: 512,
                                    cacheHeight: 512,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ),
                                        ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 48,
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                          ),
                          if (nft.hasRarity)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: NftRarityBadge(
                                label: nft.rarity,
                                rank: nft.rarityRank,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (nft.isProjectNft)
                    Container(
                      width: double.infinity,
                      color: AppColors.accentRed,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context).officialProjectNft,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nft.name,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${nft.count}x - ${nft.chainName}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollectionGrid() {
    final collections = groupNftsByCollection(_nfts);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        final cover = collection.coverAsset;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () =>
                setState(() => _selectedCollectionKey = collection.key),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: cover.imageUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.collections,
                              color: Colors.white54,
                              size: 40,
                            ),
                          )
                        : Image.network(
                            cover.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${collection.totalCount} NFTs · ${collection.chainName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _collectionKeyFor(NftAsset nft) => nftCollectionKey(nft);

  NftCollectionGroup? _selectedCollection() {
    final key = _selectedCollectionKey;
    if (key == null) return null;
    for (final collection in groupNftsByCollection(_nfts)) {
      if (collection.key == key) return collection;
    }
    return null;
  }

  Future<void> _showNftDetails(NftAsset nft) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NftDetailSheet(nft: nft),
    );
  }
}
