import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chain.dart';
import '../../../models/token.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/token_visibility_service.dart';
import '../../../utils/app_error_utils.dart';
import '../../../utils/token_visibility_utils.dart';
import '../../../utils/token_trust_utils.dart';
import '../../../utils/toast_utils.dart';
import '../../wallet/helpers/token_management_query_helper.dart';
import '../../../widgets/token_icon.dart';

class SwapTokenSelectorDialog extends StatefulWidget {
  const SwapTokenSelectorDialog({
    super.key,
    required this.tokens,
    required this.chainId,
    this.networkFamilies,
    this.activeNetworkFamily,
    this.blockUnverifiedSelection = false,
    this.tokenFilter,
  });

  final List<Token> tokens;
  final int chainId;

  /// Optional bridge-only family picker. Token balances are scoped to the
  /// active network, so selecting another family returns it to the caller,
  /// which switches the wallet network before showing that family's tokens.
  final Set<ChainFamily>? networkFamilies;
  final ChainFamily? activeNetworkFamily;
  final bool blockUnverifiedSelection;
  final bool Function(Token token)? tokenFilter;

  @override
  State<SwapTokenSelectorDialog> createState() =>
      _SwapTokenSelectorDialogState();
}

class _SwapTokenSelectorDialogState extends State<SwapTokenSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TokenVisibilityService _tokenVisibilityService =
      TokenVisibilityService();
  Timer? _searchDebounce;

  String _query = '';
  bool _isResolvingContract = false;
  bool _isAddingToken = false;
  bool _contractLookupCompleted = false;
  CustomTokenDefinition? _detectedToken;
  List<Token> _remoteResults = const [];
  bool _isSearchingRemote = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<Token> get _filteredTokens {
    final candidates = _query.isEmpty
        ? widget.tokens
        : <Token>[...widget.tokens, ..._remoteResults];
    final deduped = <String, Token>{};
    for (final token in candidates) {
      if (widget.tokenFilter != null && !widget.tokenFilter!(token)) continue;
      final key =
          (token.contractAddress?.trim().toLowerCase().isNotEmpty ?? false)
          ? token.contractAddress!.trim().toLowerCase()
          : 'native:${token.networkKey ?? widget.chainId}:${token.symbol.toUpperCase()}';
      final existing = deduped[key];
      if (existing == null || (!existing.isCertified && token.isCertified)) {
        deduped[key] = token;
      }
    }
    final filtered = _query.isEmpty
        ? deduped.values.toList()
        : TokenManagementQueryHelper.filterLocalTokens(
            deduped.values.toList(),
            _query,
          );
    filtered.sort((a, b) {
      final trustA = TokenTrustUtils.levelFor(a, chainId: widget.chainId).index;
      final trustB = TokenTrustUtils.levelFor(b, chainId: widget.chainId).index;
      final trust = trustA.compareTo(trustB);
      if (trust != 0) return trust;
      return a.symbol.toUpperCase().compareTo(b.symbol.toUpperCase());
    });
    return filtered;
  }

  bool get _isContractQuery {
    final family = context.read<BlockchainService>().activeFamily;
    return TokenManagementQueryHelper.isContractAddress(_query, family: family);
  }

  bool get _hasVisibleContractMatch {
    if (!_isContractQuery) {
      return false;
    }
    final normalized = _query.toLowerCase();
    return widget.tokens.any(
      (token) => (token.contractAddress ?? '').toLowerCase() == normalized,
    );
  }

  bool get _showContractCard {
    return _isContractQuery && !_hasVisibleContractMatch;
  }

  int? get _tokenIconChainId {
    return widget.chainId > 0 ? widget.chainId : null;
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim();
    _searchDebounce?.cancel();
    setState(() {
      _query = nextQuery;
      _detectedToken = null;
      _contractLookupCompleted = false;
      _isResolvingContract = false;
      _remoteResults = const [];
      _isSearchingRemote = false;
    });

    final family = context.read<BlockchainService>().activeFamily;
    if (!TokenManagementQueryHelper.isContractAddress(
      nextQuery,
      family: family,
    )) {
      if (nextQuery.length >= 2) {
        _searchDebounce = Timer(
          const Duration(milliseconds: 250),
          () => _searchRemote(nextQuery),
        );
      }
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _resolveContract(nextQuery),
    );
  }

  Future<void> _searchRemote(String query) async {
    if (!mounted || _query != query) return;
    setState(() => _isSearchingRemote = true);
    try {
      final results = await context
          .read<BlockchainService>()
          .searchTokensFromBackend(query, limit: 60);
      if (!mounted || _query != query) return;
      setState(() {
        _remoteResults = results;
        _isSearchingRemote = false;
      });
    } catch (_) {
      if (!mounted || _query != query) return;
      setState(() => _isSearchingRemote = false);
    }
  }

  Future<void> _resolveContract(String contractAddress) async {
    if (!mounted || _query != contractAddress) {
      return;
    }

    setState(() {
      _isResolvingContract = true;
      _contractLookupCompleted = false;
    });

    final blockchain = context.read<BlockchainService>();
    try {
      final detected = await blockchain.detectTokenByContract(contractAddress);
      if (!mounted || _query != contractAddress) {
        return;
      }
      setState(() {
        _detectedToken = detected;
        _contractLookupCompleted = true;
        _isResolvingContract = false;
      });
    } catch (_) {
      if (!mounted || _query != contractAddress) {
        return;
      }
      setState(() {
        _detectedToken = null;
        _contractLookupCompleted = true;
        _isResolvingContract = false;
      });
    }
  }

  Future<void> _handleAddDetectedToken() async {
    final l = AppLocalizations.of(context);
    final detected = _detectedToken;
    if (detected == null) {
      ToastUtils.showError(l.couldNotDetectTokenMetadata);
      return;
    }
    final detectedToken = _tokenFromDefinition(detected);
    if (widget.blockUnverifiedSelection &&
        TokenTrustUtils.blocksDestination(
          detectedToken,
          chainId: widget.chainId,
        )) {
      ToastUtils.showError(
        'This contract is not a verified destination token. Check the contract address before enabling it in Token Management.',
      );
      return;
    }

    setState(() => _isAddingToken = true);
    final blockchain = context.read<BlockchainService>();
    final normalizedAddress = detected.address.toLowerCase();

    try {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        widget.chainId,
      );
      Token selectedToken =
          _findExistingToken(blockchain, normalizedAddress) ?? detectedToken;

      if (TokenVisibilityUtils.contains(hiddenTokens, selectedToken)) {
        await _tokenVisibilityService.setTokenHidden(
          widget.chainId,
          selectedToken,
          false,
        );
      }

      final existsInWalletTokens = blockchain.tokens.any(
        (token) =>
            (token.contractAddress ?? '').toLowerCase() == normalizedAddress,
      );
      final existsAsCustom = blockchain.customTokensForActiveChain.any(
        (token) => token.address.toLowerCase() == normalizedAddress,
      );

      if (!existsInWalletTokens && !existsAsCustom) {
        await blockchain.addCustomToken(
          chainId: widget.chainId,
          token: detected,
        );
      }

      selectedToken =
          _findExistingToken(blockchain, normalizedAddress) ?? selectedToken;

      if (!mounted) {
        return;
      }
      Navigator.pop(context, selectedToken);
    } catch (error) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          error,
          fallback: l.tokenAddFailed('Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToken = false);
      }
    }
  }

  Token? _findExistingToken(
    BlockchainService blockchain,
    String normalizedAddress,
  ) {
    for (final token in blockchain.tokens) {
      if ((token.contractAddress ?? '').toLowerCase() == normalizedAddress) {
        return token;
      }
    }

    for (final token in widget.tokens) {
      if ((token.contractAddress ?? '').toLowerCase() == normalizedAddress) {
        return token;
      }
    }

    for (final token in blockchain.customTokensForActiveChain) {
      if (token.address.toLowerCase() == normalizedAddress) {
        return _tokenFromDefinition(token);
      }
    }

    return null;
  }

  Token _tokenFromDefinition(CustomTokenDefinition definition) {
    return Token(
      symbol: definition.symbol,
      name: definition.name,
      contractAddress: definition.address,
      balance: 0,
      valueUsd: 0,
      priceUsd: 0,
      changePercent24h: 0,
      decimals: definition.decimals,
      imageUrl: definition.imageUrl,
      coinGeckoId: definition.coinGeckoId,
      networkKey: definition.networkKey,
      tokenStandard: definition.tokenStandard,
      isCertified: definition.isCertified,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final networkFamilies = widget.networkFamilies;
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
            if (networkFamilies != null && networkFamilies.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final family in const [
                    ChainFamily.evm,
                    ChainFamily.solana,
                    ChainFamily.tron,
                  ])
                    if (networkFamilies.contains(family))
                      ChoiceChip(
                        key: ValueKey('bridge-family-${family.wireValue}'),
                        label: Text(switch (family) {
                          ChainFamily.evm => 'EVM',
                          ChainFamily.solana => 'Solana',
                          ChainFamily.tron => 'TRON',
                        }),
                        selected: widget.activeNetworkFamily == family,
                        onSelected: (selected) {
                          if (selected &&
                              widget.activeNetworkFamily != family) {
                            Navigator.pop(context, family);
                          }
                        },
                        selectedColor: AppColors.accentRed,
                        backgroundColor: AppColors.cardDark,
                        labelStyle: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: widget.activeNetworkFamily == family
                              ? AppColors.accentRed
                              : Colors.white12,
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l.searchTokenOrPasteContract,
                  hintStyle: GoogleFonts.outfit(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _isSearchingRemote
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          tooltip: l.clearSearch,
                          icon: const Icon(Icons.close, color: Colors.white54),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (_showContractCard) ...[
              const SizedBox(height: 14),
              _SwapContractDetectionCard(
                chainId: _tokenIconChainId,
                detectedToken: _detectedToken,
                isResolving: _isResolvingContract,
                isAdding: _isAddingToken,
                lookupCompleted: _contractLookupCompleted,
                onAdd: _handleAddDetectedToken,
                selectionBlocked:
                    widget.blockUnverifiedSelection &&
                    _detectedToken != null &&
                    TokenTrustUtils.blocksDestination(
                      _tokenFromDefinition(_detectedToken!),
                      chainId: widget.chainId,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: _filteredTokens.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _query.isEmpty
                              ? l.noTokensYet
                              : l.noMatchingTokensFound,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white54),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTokens.length,
                      itemBuilder: (context, index) {
                        final token = _filteredTokens[index];
                        return _SwapTokenOption(
                          token: token,
                          chainId: _tokenIconChainId,
                          blocked:
                              widget.blockUnverifiedSelection &&
                              TokenTrustUtils.blocksDestination(
                                token,
                                chainId: widget.chainId,
                              ),
                          onTap: () => Navigator.pop(context, token),
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

class _SwapContractDetectionCard extends StatelessWidget {
  const _SwapContractDetectionCard({
    required this.chainId,
    required this.detectedToken,
    required this.isResolving,
    required this.isAdding,
    required this.lookupCompleted,
    required this.onAdd,
    required this.selectionBlocked,
  });

  final int? chainId;
  final CustomTokenDefinition? detectedToken;
  final bool isResolving;
  final bool isAdding;
  final bool lookupCompleted;
  final VoidCallback onAdd;
  final bool selectionBlocked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasToken = detectedToken != null;

    String statusText;
    if (isResolving) {
      statusText = l.loading;
    } else if (hasToken) {
      statusText = l.tokenDetected;
    } else if (lookupCompleted) {
      statusText = l.couldNotDetectTokenMetadata;
    } else {
      statusText = l.pasteContractToAddToken;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed:
                    (!hasToken || isResolving || isAdding || selectionBlocked)
                    ? null
                    : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(72, 34),
                ),
                child: isAdding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.addToken,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
          if (hasToken) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TokenIcon(
                  tokenSymbol: detectedToken!.symbol,
                  tokenAddress: detectedToken!.address,
                  tokenImageUrl: detectedToken!.imageUrl,
                  size: 30,
                  chainId: chainId,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detectedToken!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        selectionBlocked
                            ? '${detectedToken!.symbol} · Unverified destination'
                            : detectedToken!.symbol,
                        style: GoogleFonts.outfit(
                          color: selectionBlocked
                              ? AppColors.accentRed
                              : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SwapTokenOption extends StatelessWidget {
  const _SwapTokenOption({
    required this.token,
    required this.chainId,
    required this.onTap,
    required this.blocked,
  });

  final Token token;
  final int? chainId;
  final VoidCallback onTap;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final trustLevel = TokenTrustUtils.levelFor(token, chainId: chainId ?? 0);
    return InkWell(
      onTap: blocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            TokenIcon(
              tokenSymbol: token.symbol,
              tokenAddress: token.contractAddress,
              tokenImageUrl: token.imageUrl,
              isCertified: token.isCertified,
              size: 32,
              chainId: chainId,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      TokenTrustUtils.label(token, chainId: chainId ?? 0),
                      if ((token.contractAddress ?? '').isNotEmpty)
                        TokenTrustUtils.shortenedAddress(token.contractAddress),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: blocked
                          ? AppColors.accentRed
                          : trustLevel == TokenTrustLevel.verified
                          ? Colors.greenAccent
                          : Colors.white38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: Text(
                token.balance.toStringAsFixed(4),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
