import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../models/token.dart';
import '../../widgets/token_icon.dart';

import '../../services/blockchain_service.dart';
import '../../services/home_snapshot_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/token_visibility_utils.dart';

/// Select Token Screen
/// Search and filter tokens by network, tap to select
class SelectTokenScreen extends StatefulWidget {
  const SelectTokenScreen({super.key});

  @override
  State<SelectTokenScreen> createState() => _SelectTokenScreenState();
}

class _SelectTokenScreenState extends State<SelectTokenScreen> {
  final TextEditingController _searchController = TextEditingController();

  final WalletService _walletService = WalletService();
  final TokenVisibilityService _tokenVisibilityService =
      TokenVisibilityService();
  final HomeSnapshotService _snapshotService = HomeSnapshotService();

  List<Token> _allTokens = [];
  List<Token> _filteredTokens = [];
  bool _isLoading = true;
  BlockchainService? _blockchain;
  int? _observedChainId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachBlockchainListener();
      _loadTokens();
    });
  }

  @override
  void dispose() {
    _blockchain?.removeListener(_handleBlockchainChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _attachBlockchainListener() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (identical(_blockchain, blockchain)) {
      return;
    }
    _blockchain?.removeListener(_handleBlockchainChanged);
    _blockchain = blockchain;
    _observedChainId = blockchain.activeTokenStorageChainId;
    _blockchain?.addListener(_handleBlockchainChanged);
  }

  void _handleBlockchainChanged() {
    final blockchain = _blockchain;
    if (!mounted || blockchain == null) {
      return;
    }
    final nextChainId = blockchain.activeTokenStorageChainId;
    if (_observedChainId != nextChainId) {
      _observedChainId = nextChainId;
      unawaited(_loadTokens());
      return;
    }

    final nextTokens = blockchain.tokens;
    final nextSignature = nextTokens
        .map(
          (token) =>
              '${token.contractAddress ?? token.symbol}:${token.balance}:${token.imageUrl ?? ''}:${token.coinGeckoId ?? ''}',
        )
        .toList();
    final currentSignature = _allTokens
        .map(
          (token) =>
              '${token.contractAddress ?? token.symbol}:${token.balance}:${token.imageUrl ?? ''}:${token.coinGeckoId ?? ''}',
        )
        .toList();
    if (listEquals(nextSignature, currentSignature)) {
      return;
    }
    _applyLoadedTokens(List<Token>.from(nextTokens), isLoading: false);
  }

  Future<void> _loadTokens() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    _attachBlockchainListener();
    final chainId = blockchain.activeTokenStorageChainId;
    setState(() => _isLoading = true);
    try {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        chainId,
      );
      final address = await _walletService.getActiveAddressForFamily(
        blockchain.activeFamily,
      );
      final cachedTokens = await _loadCachedTokens(
        blockchain: blockchain,
        walletAddress: address,
        chainId: chainId,
        hiddenTokens: hiddenTokens,
      );
      if (cachedTokens.isNotEmpty && mounted) {
        _applyLoadedTokens(cachedTokens, isLoading: false);
      }

      if (address != null) {
        if (!mounted) return;
        final tokens = await blockchain.fetchWalletTokens(address);
        final visibleTokens = _applyVisibility(tokens, hiddenTokens);
        if (mounted) {
          _applyLoadedTokens(visibleTokens, isLoading: false);
        }
      } else {
        // Show default token list even without wallet
        final defaultTokens = _applyVisibility(
          _getDefaultTokens(),
          hiddenTokens,
        );
        if (mounted) {
          _applyLoadedTokens(defaultTokens, isLoading: false);
        }
      }
    } catch (e) {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        chainId,
      );
      final defaultTokens = _applyVisibility(_getDefaultTokens(), hiddenTokens);
      if (mounted) {
        _applyLoadedTokens(defaultTokens, isLoading: false);
      }
    }
  }

  Future<List<Token>> _loadCachedTokens({
    required BlockchainService blockchain,
    required String? walletAddress,
    required int chainId,
    required Set<String> hiddenTokens,
  }) async {
    var cachedTokens = <Token>[];
    if (walletAddress != null && walletAddress.isNotEmpty) {
      cachedTokens = _applyVisibility(
        blockchain.getCachedWalletTokens(walletAddress, chainId: chainId),
        hiddenTokens,
      );
      if (cachedTokens.isNotEmpty) {
        return cachedTokens;
      }

      final snapshot = await _snapshotService.loadSnapshot(
        chainId,
        walletAddress,
      );
      if (snapshot != null && snapshot.tokens.isNotEmpty) {
        return _applyVisibility(snapshot.tokens, hiddenTokens);
      }
    }

    final currentTokens = _applyVisibility(blockchain.tokens, hiddenTokens);
    if (currentTokens.isNotEmpty) {
      return currentTokens;
    }

    return const [];
  }

  void _applyLoadedTokens(List<Token> tokens, {required bool isLoading}) {
    setState(() {
      _allTokens = tokens;
      _filteredTokens = tokens;
      _isLoading = isLoading;
    });
    if (_searchController.text.isNotEmpty) {
      _filterTokens(_searchController.text);
    }
  }

  List<Token> _applyVisibility(List<Token> tokens, Set<String> hiddenTokens) {
    return tokens.where((token) {
      final contractAddress = token.contractAddress ?? '';
      if (contractAddress.isEmpty) {
        return true;
      }
      return !TokenVisibilityUtils.contains(hiddenTokens, token);
    }).toList();
  }

  List<Token> _getDefaultTokens() {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (blockchain.activeFamily != ChainFamily.evm) {
      return [blockchain.activeNativeToken];
    }
    return [
      Token(
        symbol: 'ETH',
        name: 'Ethereum',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 18,
        coinGeckoId: 'ethereum',
      ),
      Token(
        symbol: 'BNB',
        name: 'BNB',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 18,
        coinGeckoId: 'binancecoin',
      ),
      Token(
        symbol: 'MATIC',
        name: 'Polygon',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 18,
        coinGeckoId: 'matic-network',
      ),
      Token(
        symbol: 'USDC',
        name: 'USD Coin',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 6,
        coinGeckoId: 'usd-coin',
      ),
    ];
  }

  void _filterTokens(String query) {
    setState(() {
      _filteredTokens = _allTokens.where((token) {
        final matchesSearch =
            query.isEmpty ||
            token.name.toLowerCase().contains(query.toLowerCase()) ||
            token.symbol.toLowerCase().contains(query.toLowerCase()) ||
            token.contractAddress?.toLowerCase().contains(
                  query.toLowerCase(),
                ) ==
                true;
        return matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l.selectTokenTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterTokens,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    icon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    hintText: l.searchTokenOrPasteContract,
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Token list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentRed,
                      ),
                    )
                  : _filteredTokens.isEmpty
                  ? Center(
                      child: Text(
                        l.noTokensYet,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, a) => const SizedBox(height: 8),
                      itemCount: _filteredTokens.length,
                      itemBuilder: (context, index) =>
                          _buildTokenItem(_filteredTokens[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenItem(Token token) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, token),
      child: Container(
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
              size: 42,
              chainId: Provider.of<BlockchainService>(
                context,
                listen: false,
              ).activeChain.chainId,
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
                    token.symbol,
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
                  token.balance.toStringAsFixed(2),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  token.formattedValue,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
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
