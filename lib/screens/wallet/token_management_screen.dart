import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';
import '../../utils/token_visibility_utils.dart';
import 'helpers/token_management_query_helper.dart';
import 'widgets/token_management/contract_import_card.dart';
import 'widgets/token_management/managed_token_tile.dart';
import 'widgets/token_management/token_management_search_bar.dart';

/// MetaMask / TrustWallet style token manager with instant toggles.
class TokenManagementScreen extends StatefulWidget {
  const TokenManagementScreen({super.key});

  @override
  State<TokenManagementScreen> createState() => _TokenManagementScreenState();
}

class _TokenManagementScreenState extends State<TokenManagementScreen> {
  final WalletService _walletService = WalletService();
  final TokenVisibilityService _visibilityService = TokenVisibilityService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // ── State ──────────────────────────────────
  List<Token> _walletTokens = [];
  List<Token> _suggestedTokens = [];
  List<Token> _remoteResults = [];
  Set<String> _hiddenKeys = {};
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isSearchingRemote = false;
  bool _hasCheckedClipboard = false;
  String _query = '';

  // Contract import
  String? _resolvingContract;
  String? _resolvedTokenName;
  String? _resolvedTokenSymbol;
  String? _resolvedTokenImageUrl;

  // Tokens being toggled (optimistic state tracking)
  final Set<String> _processingTokens = {};

  // In-memory search cache: "networkKey:query" → results
  final Map<String, List<Token>> _searchCache = {};
  BlockchainService? _blockchain;
  String? _observedNetworkKey;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachBlockchainListener();
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _blockchain?.removeListener(_handleBlockchainChanged);
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _attachBlockchainListener() {
    final blockchain = context.read<BlockchainService>();
    if (identical(_blockchain, blockchain)) {
      return;
    }
    _blockchain?.removeListener(_handleBlockchainChanged);
    _blockchain = blockchain;
    _observedNetworkKey = blockchain.activeNetworkKey;
    _blockchain?.addListener(_handleBlockchainChanged);
  }

  /// Returns a stable integer key for [TokenVisibilityService] that is unique
  /// per network family. EVM uses the real chainId; non-EVM uses negative
  /// BIP-44 coin-type sentinels that cannot collide with any real chain ID.
  int _effectiveChainId(BlockchainService blockchain) =>
      switch (blockchain.activeFamily) {
        ChainFamily.evm => blockchain.activeChain.chainId,
        ChainFamily.solana => -501,
        ChainFamily.tron => -195,
      };

  void _handleBlockchainChanged() {
    final blockchain = _blockchain;
    if (!mounted || blockchain == null) {
      return;
    }

    final nextNetworkKey = blockchain.activeNetworkKey;
    if (_observedNetworkKey != nextNetworkKey) {
      _observedNetworkKey = nextNetworkKey;
      unawaited(_loadData(showSpinner: false));
      return;
    }

    final nextTokens = List<Token>.from(blockchain.tokens);
    final nextSignature = nextTokens
        .map(
          (token) =>
              '${token.contractAddress ?? token.symbol}:${token.balance}:${token.imageUrl ?? ''}:${token.coinGeckoId ?? ''}',
        )
        .toList();
    final currentSignature = _walletTokens
        .map(
          (token) =>
              '${token.contractAddress ?? token.symbol}:${token.balance}:${token.imageUrl ?? ''}:${token.coinGeckoId ?? ''}',
        )
        .toList();
    if (listEquals(nextSignature, currentSignature)) {
      return;
    }

    setState(() {
      _walletTokens = nextTokens;
    });
  }

  // ── Data Loading ───────────────────────────

  Future<void> _loadData({bool showSpinner = true}) async {
    final blockchain = context.read<BlockchainService>();
    _attachBlockchainListener();
    if (!mounted) return;
    final effectiveChainId = _effectiveChainId(blockchain);
    final isEvm = blockchain.activeFamily == ChainFamily.evm;
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final hidden = await _visibilityService.loadHiddenTokens(effectiveChainId);
    final address = isEvm
        ? await _walletService.getCurrentWalletAddress()
        : await _walletService.getWalletAddressForFamily(
            blockchain.activeFamily,
          );
    List<Token> fetched = blockchain.tokens;
    if (isEvm && address != null && address.isNotEmpty) {
      final state = blockchain.getWalletTokenState(
        address,
        chainId: blockchain.activeChain.chainId,
      );
      final cached = state.tokens.isNotEmpty
          ? state.tokens
          : blockchain.getCachedWalletTokens(
              address,
              chainId: blockchain.activeChain.chainId,
            );
      if (cached.isNotEmpty) {
        fetched = List<Token>.from(cached);
      }
    }
    // For non-EVM, keep the spinner running until the background refresh
    // delivers real data — either the list is empty, or the cached tokens
    // belong to a different network (stale EVM tokens visible after switch).
    final hasWrongNetworkTokens =
        fetched.isNotEmpty &&
        fetched.any((t) => t.networkKey != blockchain.activeNetworkKey);
    final keepSpinner =
        !isEvm && (fetched.isEmpty || hasWrongNetworkTokens) && address != null;
    if (mounted) {
      setState(() {
        _walletTokens = fetched;
        _hiddenKeys = hidden;
        _isLoading = keepSpinner;
      });
    }

    // Load suggested tokens in background (non-blocking first paint)
    _loadSuggestedTokens();
    _checkClipboardForTokenSuggestion();
    if (address != null) {
      unawaited(
        _refreshWalletTokensInBackground(
          blockchain,
          walletAddress: address,
          effectiveChainId: effectiveChainId,
          hidden: hidden,
        ),
      );
    }
  }

  Future<void> _refreshWalletTokensInBackground(
    BlockchainService blockchain, {
    required String walletAddress,
    required int effectiveChainId,
    required Set<String> hidden,
  }) async {
    try {
      // Passing no chainId lets BlockchainService use activeNetworkKey for
      // non-EVM families, which correctly targets the Solana/Tron endpoint.
      final fetched = await blockchain.refreshWalletTokens(walletAddress);
      if (!mounted) {
        return;
      }
      setState(() {
        _walletTokens = fetched;
        _hiddenKeys = hidden;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error refreshing tokens in manager: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSuggestedTokens() async {
    final blockchain = context.read<BlockchainService>();
    // Token search is EVM-only; the backend catalog has no SPL/TRC-20 directory.
    if (blockchain.activeFamily != ChainFamily.evm) return;
    try {
      final results = await blockchain.searchTokensFromBackend('', limit: 60);
      if (!mounted) return;
      setState(() {
        _suggestedTokens = results;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestedTokens = [];
      });
    }
  }

  // ── Token Identity & Enabled Logic ─────────

  String _tokenKey(Token token) => TokenVisibilityUtils.identifier(token);

  bool _isTokenEnabled(Token token) {
    // Native token (no contract) is always enabled
    if (token.contractAddress == null || token.contractAddress!.isEmpty) {
      return true;
    }
    // If it's in hidden set, it's disabled
    if (_hiddenKeys.contains(_tokenKey(token))) return false;
    // If it's in wallet tokens or custom tokens, it's enabled
    if (_walletTokens.any(
      (t) =>
          (t.contractAddress ?? '').toLowerCase() ==
          (token.contractAddress ?? '').toLowerCase(),
    )) {
      return true;
    }
    // Check custom tokens
    final blockchain = context.read<BlockchainService>();
    final customs = blockchain.customTokensForActiveChain;
    return customs.any(
      (c) =>
          c.address.toLowerCase() ==
          (token.contractAddress ?? '').toLowerCase(),
    );
  }

  bool _isNativeToken(Token token) {
    return token.contractAddress == null || token.contractAddress!.isEmpty;
  }

  void _syncWalletTokensFromBlockchain(BlockchainService blockchain) {
    _walletTokens = List<Token>.from(blockchain.tokens);
  }

  // ── Optimistic Toggle ──────────────────────

  Future<void> _handleToggle(Token token, bool enable) async {
    final l = AppLocalizations.of(context);
    final blockchain = context.read<BlockchainService>();
    final isEvm = blockchain.activeFamily == ChainFamily.evm;
    final chainId = _effectiveChainId(blockchain);
    final key = _tokenKey(token);
    final contract = token.contractAddress;
    if (_processingTokens.contains(key)) return;

    // Optimistic UI update
    setState(() {
      _processingTokens.add(key);
      if (enable) {
        _hiddenKeys.remove(key);
      } else {
        _hiddenKeys.add(key);
      }
    });

    try {
      if (enable) {
        // Enabling: unhide the token, and add as custom if not already in wallet
        await _visibilityService.setTokenHidden(chainId, token, false);

        // Custom token registration is EVM-only. On Solana/Tron the backend
        // already surfaces all known tokens via the wallet-tokens endpoint.
        if (isEvm) {
          final existsInWallet = _walletTokens.any(
            (t) =>
                (t.contractAddress ?? '').toLowerCase() ==
                (contract ?? '').toLowerCase(),
          );
          final existsAsCustom = blockchain.customTokensForActiveChain.any(
            (c) => c.address.toLowerCase() == (contract ?? '').toLowerCase(),
          );

          if (!existsInWallet &&
              !existsAsCustom &&
              contract != null &&
              contract.isNotEmpty) {
            final detected = await blockchain.detectTokenByContract(contract);
            final tokenToAdd = CustomTokenDefinition(
              symbol: (detected?.symbol ?? token.symbol).toUpperCase(),
              name: detected?.name ?? token.name,
              address: detected?.address ?? contract,
              decimals: (detected?.decimals ?? token.decimals) > 0
                  ? (detected?.decimals ?? token.decimals)
                  : 18,
              coinGeckoId: token.coinGeckoId ?? detected?.coinGeckoId,
              imageUrl: token.imageUrl ?? detected?.imageUrl,
            );
            await blockchain.addCustomToken(
              chainId: blockchain.activeChain.chainId,
              token: tokenToAdd,
            );
          }
        }
      } else {
        // Disabling: hide the token
        await _visibilityService.setTokenHidden(chainId, token, true);
      }

      if (!mounted) return;
      setState(() {
        _syncWalletTokensFromBlockchain(blockchain);
        _hasChanges = true;
        _processingTokens.remove(key);
      });
    } catch (e) {
      // Revert optimistic update
      if (!mounted) return;
      setState(() {
        if (enable) {
          _hiddenKeys.add(key);
        } else {
          _hiddenKeys.remove(key);
        }
        _processingTokens.remove(key);
      });
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.tokenAddFailed('Please try again.'),
        ),
      );
    }
  }

  // ── Search ─────────────────────────────────

  void _handleSearchChanged() {
    if (!mounted) return;
    final nextQuery = _searchController.text.trim();
    setState(() {
      _query = nextQuery;
      _resolvedTokenName = null;
      _resolvedTokenSymbol = null;
      _resolvedTokenImageUrl = null;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (TokenManagementQueryHelper.isContractAddress(nextQuery)) {
        _autoResolveContract(nextQuery);
      } else {
        _runRemoteSearch(nextQuery);
      }
    });
  }

  Future<void> _autoResolveContract(String contractAddress) async {
    final blockchain = context.read<BlockchainService>();
    try {
      final token = await blockchain.detectTokenByContract(contractAddress);
      if (!mounted || _query.trim() != contractAddress) return;
      if (token != null) {
        setState(() {
          _resolvedTokenName = token.name;
          _resolvedTokenSymbol = token.symbol;
          _resolvedTokenImageUrl = token.imageUrl;
        });
      }
    } catch (_) {}
  }

  Future<void> _runRemoteSearch(String query) async {
    final trimmed = query.trim();
    if (!mounted) return;

    if (trimmed.isEmpty || trimmed.length < 2) {
      setState(() {
        _isSearchingRemote = false;
        _remoteResults = [];
      });
      return;
    }
    if (TokenManagementQueryHelper.isContractAddress(trimmed)) {
      setState(() {
        _isSearchingRemote = false;
        _remoteResults = [];
      });
      return;
    }

    final blockchain = context.read<BlockchainService>();
    // Remote token search is EVM-only.
    if (blockchain.activeFamily != ChainFamily.evm) {
      setState(() {
        _isSearchingRemote = false;
        _remoteResults = [];
      });
      return;
    }
    final cacheKey = '${blockchain.activeNetworkKey}:${trimmed.toLowerCase()}';

    // Show cached results immediately
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      setState(() => _remoteResults = cached);
    }

    setState(() => _isSearchingRemote = true);
    try {
      final results = await blockchain.searchTokensFromBackend(
        trimmed,
        limit: 60,
      );
      if (!mounted || trimmed != _query.trim()) return;
      _searchCache[cacheKey] = results;
      setState(() {
        _remoteResults = results;
        _isSearchingRemote = false;
      });
    } catch (_) {
      if (!mounted || trimmed != _query.trim()) return;
      setState(() => _isSearchingRemote = false);
    }
  }

  // ── Contract Import ────────────────────────

  bool _tokenExistsForAddress(String contractAddress) {
    final normalized = contractAddress.toLowerCase();
    return _walletTokens.any(
      (t) => (t.contractAddress ?? '').toLowerCase() == normalized,
    );
  }

  Future<void> _importTokenFromContract() async {
    final l = AppLocalizations.of(context);
    if (!TokenManagementQueryHelper.isContractAddress(_query)) return;
    final blockchain = context.read<BlockchainService>();
    if (_tokenExistsForAddress(_query)) {
      ToastUtils.showInfo(l.tokenAlreadyAvailable);
      return;
    }

    setState(() => _resolvingContract = _query);
    try {
      final token = await blockchain.detectTokenByContract(_query);
      if (token == null) {
        ToastUtils.showError(l.couldNotDetectTokenMetadata);
        return;
      }
      final added = await blockchain.addCustomToken(
        chainId: blockchain.activeChain.chainId,
        token: token,
      );
      if (!added) {
        ToastUtils.showInfo(l.tokenAlreadyExistsOnNetwork);
        return;
      }
      if (!mounted) return;
      setState(() {
        _syncWalletTokensFromBlockchain(blockchain);
        _hasChanges = true;
        _searchController.clear();
      });
      ToastUtils.showSuccess(l.tokenAdded(token.symbol));
    } catch (e) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.tokenAddFailed('Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingContract = null);
    }
  }

  // ── Clipboard auto-detect ──────────────────

  Future<void> _checkClipboardForTokenSuggestion() async {
    final l = AppLocalizations.of(context);
    if (_hasCheckedClipboard || !mounted) return;
    _hasCheckedClipboard = true;
    // Contract auto-detection only applies to EVM (0x… addresses).
    final blockchain = context.read<BlockchainService>();
    if (blockchain.activeFamily != ChainFamily.evm) return;

    try {
      final data = await Clipboard.getData('text/plain');
      if (!mounted) return;
      final clipboardText = data?.text?.trim() ?? '';
      if (!TokenManagementQueryHelper.isContractAddress(clipboardText)) return;
      if (_tokenExistsForAddress(clipboardText)) return;

      final detected = await blockchain.detectTokenByContract(clipboardText);
      if (detected == null || !mounted) return;

      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l.tokenDetected,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.contractAddressLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      clipboardText,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${detected.name}\n${detected.symbol}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                l.ignore,
                style: GoogleFonts.outfit(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.background,
              ),
              child: Text(
                l.addToken,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      if (shouldAdd != true || !mounted) return;
      final added = await blockchain.addCustomToken(
        chainId: blockchain.activeChain.chainId,
        token: detected,
      );
      if (!added) {
        ToastUtils.showInfo(l.tokenAlreadyExistsOnNetwork);
        return;
      }
      if (!mounted) return;
      setState(() {
        _syncWalletTokensFromBlockchain(blockchain);
        _hasChanges = true;
      });
      ToastUtils.showSuccess(l.tokenAdded(detected.symbol));
    } catch (e, stackTrace) {
      debugPrint('Token clipboard suggestion error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  // ── Build unified token list ───────────────

  List<Token> _buildDisplayList() {
    final query = _query.trim().toLowerCase();
    final isContract = TokenManagementQueryHelper.isContractAddress(_query);
    if (isContract) return _walletTokens;

    // Determine source list
    List<Token> sourceTokens;
    if (query.isNotEmpty && query.length >= 2 && _remoteResults.isNotEmpty) {
      // Merge: wallet tokens + remote results, deduplicated
      sourceTokens = _deduplicateTokens([..._walletTokens, ..._remoteResults]);
    } else if (query.isEmpty && _suggestedTokens.isNotEmpty) {
      sourceTokens = _deduplicateTokens([
        ..._walletTokens,
        ..._suggestedTokens,
      ]);
    } else {
      sourceTokens = _walletTokens;
    }

    // Filter by query
    if (query.isEmpty) return sourceTokens;
    return TokenManagementQueryHelper.filterLocalTokens(sourceTokens, query);
  }

  List<Token> _deduplicateTokens(List<Token> tokens) {
    final seen = <String>{};
    final result = <Token>[];
    for (final token in tokens) {
      final key = (token.contractAddress ?? token.symbol).toLowerCase();
      if (seen.add(key)) {
        result.add(token);
      }
    }
    return result;
  }

  // ── UI ─────────────────────────────────────

  void _closeScreen() {
    Navigator.pop(context, _hasChanges);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blockchain = context.watch<BlockchainService>();
    final canImportByContract = TokenManagementQueryHelper.isContractAddress(
      _query,
    );
    final displayTokens = _buildDisplayList();
    final query = _query.trim().toLowerCase();
    final showingSuggestions = query.isEmpty && _suggestedTokens.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _closeScreen();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _closeScreen,
          ),
          title: Text(
            l.manageTokens,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentRed),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: TokenManagementSearchBar(
                      controller: _searchController,
                      query: _query,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Search status indicator
                  if (_isSearchingRemote)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.accentRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.searchResults,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Contract import card
                  if (canImportByContract)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: ContractImportCard(
                        isLoading: _resolvingContract == _query,
                        onAdd: _importTokenFromContract,
                        tokenName: _resolvedTokenName,
                        tokenSymbol: _resolvedTokenSymbol,
                        tokenImageUrl: _resolvedTokenImageUrl,
                        chainId: blockchain.activeChain.chainId,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Section label
                  if (!canImportByContract)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          query.isEmpty
                              ? (showingSuggestions
                                    ? l.suggestedTokens
                                    : l.visibleTokens)
                              : l.searchResults,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  // Unified token list
                  Expanded(
                    child: displayTokens.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                query.isEmpty
                                    ? (showingSuggestions
                                          ? l.noSuggestedTokensYet
                                          : l.noTokensDetectedYet)
                                    : l.noMatchingTokensFound,
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: displayTokens.length,
                            itemBuilder: (context, index) {
                              final token = displayTokens[index];
                              final key = _tokenKey(token);
                              final isNative = _isNativeToken(token);
                              final isEnabled = _isTokenEnabled(token);
                              final isProcessing = _processingTokens.contains(
                                key,
                              );

                              return ManagedTokenTile(
                                key: ValueKey(key),
                                token: token,
                                isEnabled: isEnabled,
                                isNative: isNative,
                                isProcessing: isProcessing,
                                onToggleChanged: (value) =>
                                    _handleToggle(token, value),
                                chainId:
                                    blockchain.activeFamily == ChainFamily.evm
                                    ? blockchain.activeChain.chainId
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
