import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/blockchain_service.dart';
import '../../services/wallet_service.dart';
import '../../l10n/app_localizations.dart';

/// NFT Gallery Screen
/// Shows NFTs owned by the wallet on the active chain
class NftGalleryScreen extends StatefulWidget {
  const NftGalleryScreen({super.key});

  @override
  State<NftGalleryScreen> createState() => _NftGalleryScreenState();
}

class _NftGalleryScreenState extends State<NftGalleryScreen> {
  final WalletService _walletService = WalletService();
  List<Map<String, dynamic>> _nfts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNfts();
  }

  // Project NFT associated with the application
  static const String _projectNftAddress = '0x09A3Dc6ceB95D741E6445B0227B0939C27E5Dd52';

  String _parseImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String parsedUrl = url.trim();
    if (parsedUrl.startsWith('ipfs://')) {
      parsedUrl = parsedUrl.replaceFirst('ipfs://', 'https://ipfs.io/ipfs/');
    } else if (parsedUrl.startsWith('ar://')) {
      parsedUrl = parsedUrl.replaceFirst('ar://', 'https://arweave.net/');
    }
    return parsedUrl;
  }

  Future<void> _fetchNfts() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final chain = blockchain.activeChain;
      
      final address = await _walletService.getCurrentWalletAddress();

      // Ensure the network is supported by Alchemy NFT API via proxy
      if (![1, 137, 10, 42161, 8453].contains(chain.chainId)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'NFT gallery not supported on ${chain.name} yet.\nSwitch to Ethereum, Polygon, Arbitrum, Optimism, or Base.';
        });
        return;
      }

      if (address == null) {
        setState(() { _isLoading = false; _errorMessage = 'No wallet found'; });
        return;
      }

      // 10.0.2.2 is mapped to the host's localhost for Android emulators
      final baseUrl = 'https://fomowl-backend.onrender.com/api/blockchain';
      final url = Uri.parse('$baseUrl/${chain.chainId}/nfts/$address');
      
      final response = await http.get(url).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ownedNfts = data['ownedNfts'] as List<dynamic>? ?? [];
        
        final parsedNfts = ownedNfts.map<Map<String, dynamic>>((nft) {
          final contract = nft['contract'] ?? {};
          final image = nft['image'] ?? {};
          final contractAddress = contract['address']?.toString() ?? '';
          return {
            'name': nft['name'] ?? contract['name'] ?? 'Unknown Token',
            'collection': contract['name'] ?? 'Unknown Collection',
            'count': int.tryParse(nft['balance']?.toString() ?? '1') ?? 1,
            'chain': chain.name,
            'imageUrl': _parseImageUrl(image['cachedUrl'] ?? image['originalUrl']),
            'isProjectNft': contractAddress.toLowerCase() == _projectNftAddress.toLowerCase(),
          };
        }).toList();

        if (mounted) {
          setState(() {
            _nfts = parsedNfts;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Alchemy API Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load NFTs: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    l.nftCollection,
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const Spacer(),
                  // Chain badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      Provider.of<BlockchainService>(context).activeChain.symbol,
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppColors.accentRed),
                        const SizedBox(height: 16),
                        Text('Scanning for NFTs...', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54)),
                      ],
                    ),
                  )
                : _errorMessage != null
                  ? _buildErrorState()
                  : _nfts.isEmpty
                    ? _buildEmptyState(l)
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
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.collections_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
            ),
            const SizedBox(height: 24),
            Text(
              l.noNftsYet,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Your NFT collection will appear here.\nBuy or receive NFTs on any supported chain.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _fetchNfts,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, color: AppColors.accentRed, size: 18),
                    const SizedBox(width: 8),
                    Text('Refresh', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentRed)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: AppColors.error.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Failed to load NFTs', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _fetchNfts,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Try Again', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNftGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _nfts.length,
      itemBuilder: (context, index) {
        final nft = _nfts[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: (nft['imageUrl'] != null && nft['imageUrl'].toString().isNotEmpty)
                        ? Image.network(
                            nft['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Icon(Icons.broken_image, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.image, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                          ),
                  ),
                ),
              ),
              
              // Project Badge
              if (nft['isProjectNft'] == true)
                Container(
                  width: double.infinity,
                  color: AppColors.accentRed,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  child: Text('Official Project NFT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nft['name'] ?? 'NFT',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${nft['count']}x · ${nft['chain']}',
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
