import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../widgets/token_icon.dart';

import '../../services/blockchain_service.dart';
import '../../services/home_snapshot_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/token_visibility_utils.dart';
import '../home/home_portfolio_repository.dart';

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
  final HomePortfolioRepository _portfolioRepository =
      const HomePortfolioRepository();

  List<Token> _allTokens = [];
  List<Token> _filteredTokens = [];
  Set<String> _hiddenTokens = <String>{};
  bool _isLoading = true;
  BlockchainService? _blockchain;
  int? _observedChainId;
  String _observedWalletTokenSignature = '';
  Timer? _searchDebounce;
  int _searchRequestId = 0;

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
    _searchDebounce?.cancel();
    _searchRequestId++;
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
    _observedWalletTokenSignature = _walletTokenSignature(blockchain.tokens);
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

    final nextSignature = _walletTokenSignature(blockchain.tokens);
    if (nextSignature == _observedWalletTokenSignature) {
      return;
    }
    _observedWalletTokenSignature = nextSignature;
    unawaited(_loadTokens());
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
      _hiddenTokens = hiddenTokens;
      final address = await _walletService.getActiveAddressForFamily(
        blockchain.activeFamily,
      );
      final cachedTokens = await _loadCachedTokens(
        blockchain: blockchain,
        walletAddress: address,
        chainId: chainId,
        hiddenTokens: hiddenTokens,
      );
      var mergedTokens = _mergeSelectableTokens(
        blockchain: blockchain,
        hiddenTokens: hiddenTokens,
        tokenGroups: [
          _getDefaultTokens(),
          cachedTokens,
          _customTokensForActiveNetwork(blockchain),
        ],
      );
      if (mergedTokens.isNotEmpty && mounted) {
        _applyLoadedTokens(mergedTokens, isLoading: false);
      }

      if (address != null) {
        if (!mounted) return;
        final tokens = await blockchain.fetchWalletTokens(address);
        _observedWalletTokenSignature = _walletTokenSignature(
          blockchain.tokens,
        );
        mergedTokens = _mergeSelectableTokens(
          blockchain: blockchain,
          hiddenTokens: hiddenTokens,
          tokenGroups: [
            mergedTokens,
            tokens,
            _customTokensForActiveNetwork(blockchain),
          ],
        );
        if (mounted) {
          _applyLoadedTokens(mergedTokens, isLoading: false);
        }
      }

      if (mounted) {
        _applyLoadedTokens(
          mergedTokens.isNotEmpty ? mergedTokens : _getDefaultTokens(),
          isLoading: false,
        );
      }
    } catch (e) {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        chainId,
      );
      _hiddenTokens = hiddenTokens;
      final defaultTokens = _mergeSelectableTokens(
        blockchain: blockchain,
        hiddenTokens: hiddenTokens,
        tokenGroups: [
          _getDefaultTokens(),
          _customTokensForActiveNetwork(blockchain),
        ],
      );
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
    return [blockchain.activeNativeToken];
  }

  List<Token> _customTokensForActiveNetwork(BlockchainService blockchain) {
    return blockchain.customTokensForActiveChain.map((token) {
      return Token(
        symbol: token.symbol,
        name: token.name,
        contractAddress: token.address,
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        decimals: token.decimals,
        imageUrl: token.imageUrl,
        coinGeckoId: token.coinGeckoId,
        isCertified: false,
        networkKey: token.networkKey ?? blockchain.activeNetworkKey,
        tokenStandard: token.tokenStandard,
      );
    }).toList();
  }

  List<Token> _mergeSelectableTokens({
    required BlockchainService blockchain,
    required Set<String> hiddenTokens,
    required List<List<Token>> tokenGroups,
  }) {
    final customAddresses = blockchain.customTokensForActiveChain
        .map((token) => token.address.trim().toLowerCase())
        .where((address) => address.isNotEmpty)
        .toSet();
    final visibleTokens = _portfolioRepository.prepareVisibleTokens(
      tokenGroups
          .expand((tokens) => tokens)
          .where((token) => _tokenMatchesActiveNetwork(token, blockchain))
          .toList(),
      hiddenTokens,
      userAddedAddresses: customAddresses,
    );
    final byKey = <String, Token>{};
    for (final token in visibleTokens) {
      final scopedKey = _tokenScopedKey(token, blockchain.activeNetworkKey);
      final existing = byKey[scopedKey];
      if (existing == null || _shouldReplaceToken(existing, token)) {
        byKey[scopedKey] = token.networkKey == null
            ? token.copyWith(networkKey: blockchain.activeNetworkKey)
            : token;
      }
    }
    final nativeKey = _tokenScopedKey(
      blockchain.activeNativeToken,
      blockchain.activeNetworkKey,
    );
    final native = byKey.remove(nativeKey) ?? blockchain.activeNativeToken;
    final rest = byKey.values.toList()
      ..sort((left, right) => left.symbol.compareTo(right.symbol));
    return [native, ...rest];
  }

  bool _tokenMatchesActiveNetwork(Token token, BlockchainService blockchain) {
    final expectedKey = blockchain.activeNetworkKey.trim().toLowerCase();
    final tokenKey = token.networkKey?.trim().toLowerCase();
    if (tokenKey != null && tokenKey.isNotEmpty) {
      return tokenKey == expectedKey;
    }

    if (blockchain.activeFamily == ChainFamily.evm) {
      return true;
    }

    final contract = token.contractAddress?.trim();
    final isNative = contract == null || contract.isEmpty;
    return isNative &&
        token.symbol.trim().toUpperCase() ==
            blockchain.activeNetworkSymbol.trim().toUpperCase();
  }

  String _tokenScopedKey(Token token, String activeNetworkKey) {
    final scope = token.networkKey?.trim().toLowerCase() ?? activeNetworkKey;
    final identity = token.contractAddress?.trim().isNotEmpty == true
        ? token.contractAddress!.trim().toLowerCase()
        : token.symbol.trim().toLowerCase();
    return '$scope:$identity';
  }

  bool _shouldReplaceToken(Token current, Token next) {
    if (current.balance != next.balance) {
      return next.balance > current.balance;
    }
    if (current.totalValueUsd != next.totalValueUsd) {
      return next.totalValueUsd > current.totalValueUsd;
    }
    if (!current.isCertified && next.isCertified) {
      return true;
    }
    if ((current.imageUrl == null || current.imageUrl!.isEmpty) &&
        next.imageUrl != null &&
        next.imageUrl!.isNotEmpty) {
      return true;
    }
    return current.tokenStandard == TokenStandard.erc20 &&
        next.tokenStandard != TokenStandard.erc20;
  }

  String _walletTokenSignature(List<Token> tokens) {
    return tokens
        .map(
          (token) =>
              '${token.networkKey ?? ''}:${token.contractAddress ?? token.symbol}:${token.balance}:${token.imageUrl ?? ''}:${token.coinGeckoId ?? ''}',
        )
        .join('|');
  }

  void _filterTokens(String query) {
    _searchDebounce?.cancel();
    final normalizedQuery = query.trim().toLowerCase();
    final localResults = _localSearchResults(normalizedQuery);
    setState(() {
      _filteredTokens = localResults;
    });
    if (normalizedQuery.length < 2) {
      _searchRequestId++;
      return;
    }
    final requestId = ++_searchRequestId;
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(
        _runRemoteSearch(
          normalizedQuery,
          requestId: requestId,
          localResults: localResults,
        ),
      ),
    );
  }

  List<Token> _localSearchResults(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return List<Token>.from(_allTokens);
    }
    return _allTokens.where((token) {
      return token.name.toLowerCase().contains(normalizedQuery) ||
          token.symbol.toLowerCase().contains(normalizedQuery) ||
          token.contractAddress?.toLowerCase().contains(normalizedQuery) ==
              true;
    }).toList();
  }

  Future<void> _runRemoteSearch(
    String query, {
    required int requestId,
    required List<Token> localResults,
  }) async {
    final blockchain = _blockchain;
    if (blockchain == null) return;
    try {
      final remoteResults = await blockchain.searchTokensFromBackend(
        query,
        limit: 30,
      );
      if (!mounted ||
          requestId != _searchRequestId ||
          _searchController.text.trim().toLowerCase() != query) {
        return;
      }
      setState(() {
        _filteredTokens = _mergeExplicitSearchResults(
          blockchain: blockchain,
          localResults: localResults,
          remoteResults: remoteResults,
        );
      });
    } catch (_) {
      // Keep the local matches visible if remote discovery is unavailable.
    }
  }

  List<Token> _mergeExplicitSearchResults({
    required BlockchainService blockchain,
    required List<Token> localResults,
    required List<Token> remoteResults,
  }) {
    final byKey = <String, Token>{};
    for (final token in [...localResults, ...remoteResults]) {
      if (!_tokenMatchesActiveNetwork(token, blockchain) ||
          _applyVisibility([token], _hiddenTokens).isEmpty) {
        continue;
      }
      final key = _tokenScopedKey(token, blockchain.activeNetworkKey);
      final existing = byKey[key];
      if (existing == null || _shouldReplaceToken(existing, token)) {
        byKey[key] = token.networkKey == null
            ? token.copyWith(networkKey: blockchain.activeNetworkKey)
            : token;
      }
    }
    return byKey.values.toList()
      ..sort((left, right) => left.symbol.compareTo(right.symbol));
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
                    token.symbol.trim().isEmpty ? token.name : token.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    token.balance.toStringAsFixed(2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    token.formattedValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
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
