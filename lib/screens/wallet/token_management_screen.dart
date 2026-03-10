import 'dart:async';

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
import '../../widgets/token_icon.dart';
import 'helpers/token_management_query_helper.dart';
import 'widgets/token_management/contract_import_card.dart';
import 'widgets/token_management/managed_token_tile.dart';
import 'widgets/token_management/token_management_search_bar.dart';

/// Full-screen token manager that lets users hide tokens or add/remove custom ones.
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

  List<Token> _tokens = [];
  List<Token> _searchResults = [];
  List<Token> _suggestedTokens = [];
  Set<String> _hiddenKeys = {};
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isResolvingContract = false;
  bool _isSearchingRemote = false;
  bool _hasCheckedClipboard = false;
  String _query = '';
  // Resolved contract token metadata for display in ContractImportCard
  String? _resolvedTokenName;
  String? _resolvedTokenSymbol;
  String? _resolvedTokenImageUrl;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    final blockchain = context.read<BlockchainService>();
    final chainId = blockchain.activeChain.chainId;
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final hidden = await _visibilityService.loadHiddenTokens(chainId);
    final address = await _walletService.getCurrentWalletAddress();
    List<Token> fetched = blockchain.tokens;
    if (address != null) {
      try {
        fetched = await blockchain.fetchWalletTokens(address);
      } catch (e) {
        debugPrint('Error fetching tokens in manager: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _tokens = fetched;
      _hiddenKeys = hidden;
      if (showSpinner) {
        _isLoading = false;
      }
    });
    await _loadSuggestedTokens();

    _checkClipboardForTokenSuggestion();
  }

  Future<void> _loadSuggestedTokens() async {
    final blockchain = context.read<BlockchainService>();
    try {
      final results = await blockchain.searchTokensFromBackend('', limit: 60);
      if (!mounted) return;
      setState(() {
        _suggestedTokens = results.isNotEmpty
            ? results
            : List<Token>.from(_tokens);
        if (_query.trim().isEmpty) {
          _searchResults = _suggestedTokens;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestedTokens = List<Token>.from(_tokens);
        if (_query.trim().isEmpty) {
          _searchResults = _suggestedTokens;
        }
      });
    }
  }

  bool _isTokenHidden(Token token) {
    return _hiddenKeys.contains(TokenVisibilityUtils.identifier(token));
  }

  Future<void> _toggleToken(Token token, bool hideToken) async {
    final blockchain = context.read<BlockchainService>();
    await _visibilityService.setTokenHidden(
      blockchain.activeChain.chainId,
      token,
      hideToken,
    );
    if (!mounted) return;
    setState(() {
      final key = TokenVisibilityUtils.identifier(token);
      if (hideToken) {
        _hiddenKeys.add(key);
      } else {
        _hiddenKeys.remove(key);
      }
      _hasChanges = true;
    });
  }

  Future<void> _removeCustomToken(CustomTokenDefinition token) async {
    final l = AppLocalizations.of(context);
    final blockchain = context.read<BlockchainService>();
    await blockchain.removeCustomToken(
      blockchain.activeChain.chainId,
      token.address,
    );
    await _loadData(showSpinner: false);
    setState(() => _hasChanges = true);
    ToastUtils.showSuccess(l.tokenRemoved);
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    final nextQuery = _searchController.text.trim();
    setState(() {
      _query = nextQuery;
      // Clear resolved contract info when query changes
      _resolvedTokenName = null;
      _resolvedTokenSymbol = null;
      _resolvedTokenImageUrl = null;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
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
    } catch (_) {
      // Silently ignore — user can still tap Add to retry
    }
  }

  bool _tokenExistsForAddress(String contractAddress) {
    final normalized = contractAddress.toLowerCase();
    return _tokens.any(
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

    setState(() => _isResolvingContract = true);
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
      await _loadData(showSpinner: false);
      if (!mounted) return;
      setState(() {
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
      if (mounted) {
        setState(() => _isResolvingContract = false);
      }
    }
  }

  Future<void> _runRemoteSearch(String query) async {
    final trimmed = query.trim();
    if (!mounted) return;
    if (trimmed.isEmpty) {
      setState(() {
        _isSearchingRemote = false;
        _searchResults = _suggestedTokens;
      });
      return;
    }
    if (trimmed.length < 2) {
      final fallbackLocal = TokenManagementQueryHelper.filterLocalTokens(
        _tokens,
        trimmed,
      );
      setState(() {
        _isSearchingRemote = false;
        _searchResults = fallbackLocal;
      });
      return;
    }
    if (TokenManagementQueryHelper.isContractAddress(trimmed)) {
      setState(() {
        _isSearchingRemote = false;
        _searchResults = _suggestedTokens;
      });
      return;
    }

    setState(() => _isSearchingRemote = true);
    final blockchain = context.read<BlockchainService>();
    try {
      final results = await blockchain.searchTokensFromBackend(
        trimmed,
        limit: 60,
      );
      if (!mounted || trimmed != _query.trim()) return;
      final fallbackLocal = TokenManagementQueryHelper.filterLocalTokens(
        _tokens,
        trimmed,
      );
      setState(() {
        _searchResults = results.isNotEmpty ? results : fallbackLocal;
        _isSearchingRemote = false;
      });
    } catch (_) {
      if (!mounted || trimmed != _query.trim()) return;
      final fallbackLocal = TokenManagementQueryHelper.filterLocalTokens(
        _tokens,
        trimmed,
      );
      setState(() {
        _searchResults = fallbackLocal;
        _isSearchingRemote = false;
      });
    }
  }

  Future<void> _addSearchResultToken(Token token) async {
    final l = AppLocalizations.of(context);
    final blockchain = context.read<BlockchainService>();
    final contract = token.contractAddress;
    if (contract == null || contract.isEmpty) {
      ToastUtils.showError(l.missingTokenContractAddress);
      return;
    }
    if (_tokenExistsForAddress(contract)) {
      ToastUtils.showInfo(l.tokenAlreadyAvailable);
      return;
    }

    setState(() => _isResolvingContract = true);
    try {
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

      final added = await blockchain.addCustomToken(
        chainId: blockchain.activeChain.chainId,
        token: tokenToAdd,
      );
      if (!added) {
        ToastUtils.showInfo(l.tokenAlreadyExistsOnNetwork);
        return;
      }

      await _loadData(showSpinner: false);
      if (!mounted) return;
      setState(() => _hasChanges = true);
      ToastUtils.showSuccess(l.tokenAdded(tokenToAdd.symbol));
    } catch (e) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.tokenAddFailed('Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolvingContract = false);
    }
  }

  Future<void> _checkClipboardForTokenSuggestion() async {
    final l = AppLocalizations.of(context);
    if (_hasCheckedClipboard || !mounted) return;
    _hasCheckedClipboard = true;

    try {
      final data = await Clipboard.getData('text/plain');
      if (!mounted) return;
      final clipboardText = data?.text?.trim() ?? '';
      if (!TokenManagementQueryHelper.isContractAddress(clipboardText)) return;
      if (_tokenExistsForAddress(clipboardText)) return;

      final blockchain = context.read<BlockchainService>();
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
      await _loadData(showSpinner: false);
      if (!mounted) return;
      setState(() => _hasChanges = true);
      ToastUtils.showSuccess(l.tokenAdded(detected.symbol));
    } catch (e, stackTrace) {
      debugPrint('Token clipboard suggestion error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  void _closeScreen() {
    Navigator.pop(context, _hasChanges);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blockchain = context.watch<BlockchainService>();
    final customTokens = blockchain.customTokensForActiveChain;
    final query = _query.toLowerCase();
    final filteredTokens = TokenManagementQueryHelper.filterLocalTokens(
      _tokens,
      query,
    );
    final canImportByContract = TokenManagementQueryHelper.isContractAddress(
      _query,
    );
    final hasRemoteResults =
        _isSearchingRemote || _searchResults.isNotEmpty || _query.isNotEmpty;

    return Scaffold(
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
          : RefreshIndicator(
              color: AppColors.accentRed,
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  TokenManagementSearchBar(
                    controller: _searchController,
                    query: _query,
                  ),
                  const SizedBox(height: 12),
                  if (canImportByContract)
                    ContractImportCard(
                      isLoading: _isResolvingContract,
                      onAdd: _importTokenFromContract,
                      tokenName: _resolvedTokenName,
                      tokenSymbol: _resolvedTokenSymbol,
                      tokenImageUrl: _resolvedTokenImageUrl,
                      chainId: blockchain.activeChain.chainId,
                    ),
                  // ── Visible Tokens (toggles) — at the top ──
                  Text(
                    l.visibleTokens,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filteredTokens.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _query.isEmpty
                            ? l.noTokensDetectedYet
                            : l.noMatchingTokensFound,
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                    )
                  else
                    ...filteredTokens.map(
                      (token) => ManagedTokenTile(
                        token: token,
                        isVisible: !_isTokenHidden(token),
                        onVisibilityChanged: (value) =>
                            _toggleToken(token, !value),
                        chainId: blockchain.activeChain.chainId,
                      ),
                    ),
                  // ── Added Tokens (custom imports) ──
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.addedTokens,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (customTokens.isEmpty)
                    Text(
                      l.pasteContractToAddToken,
                      style: GoogleFonts.outfit(color: Colors.white54),
                    )
                  else
                    ...customTokens.map(
                      (custom) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    custom.name,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    custom.address,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => _removeCustomToken(custom),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // ── Search Results / Suggested Tokens ──
                  if (hasRemoteResults) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          _query.isEmpty ? l.suggestedTokens : l.searchResults,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isSearchingRemote)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentRed,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!_isSearchingRemote && _searchResults.isEmpty)
                      Text(
                        _query.isEmpty
                            ? l.noSuggestedTokensYet
                            : l.noRemoteTokensFound,
                        style: GoogleFonts.outfit(color: Colors.white54),
                      )
                    else
                      ..._searchResults.map((token) {
                        final exists = _tokenExistsForAddress(
                          token.contractAddress ?? '',
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
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
                                size: 36,
                                chainId: blockchain.activeChain.chainId,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      token.name,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      token.symbol,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (exists)
                                Text(
                                  l.added,
                                  style: GoogleFonts.outfit(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                TextButton(
                                  onPressed: _isResolvingContract
                                      ? null
                                      : () => _addSearchResultToken(token),
                                  child: Text(
                                    l.addToken,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.accentRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
    );
  }
}
