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
import '../../../utils/toast_utils.dart';
import '../../wallet/helpers/token_management_query_helper.dart';
import '../../../widgets/token_icon.dart';

class SwapTokenSelectorDialog extends StatefulWidget {
  const SwapTokenSelectorDialog({
    super.key,
    required this.tokens,
    required this.chainId,
  });

  final List<Token> tokens;
  final int chainId;

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
    if (_query.isEmpty) {
      return widget.tokens;
    }
    return TokenManagementQueryHelper.filterLocalTokens(widget.tokens, _query);
  }

  bool get _isContractQuery {
    return TokenManagementQueryHelper.isContractAddress(_query);
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
    });

    if (!TokenManagementQueryHelper.isContractAddress(nextQuery)) {
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _resolveContract(nextQuery),
    );
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

    setState(() => _isAddingToken = true);
    final blockchain = context.read<BlockchainService>();
    final normalizedAddress = detected.address.toLowerCase();

    try {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        widget.chainId,
      );
      Token selectedToken =
          _findExistingToken(blockchain, normalizedAddress) ??
          _tokenFromDefinition(detected);

      if (hiddenTokens.contains(normalizedAddress)) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                  suffixIcon: _query.isEmpty
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
  });

  final int? chainId;
  final CustomTokenDefinition? detectedToken;
  final bool isResolving;
  final bool isAdding;
  final bool lookupCompleted;
  final VoidCallback onAdd;

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
                onPressed: (!hasToken || isResolving || isAdding)
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
                        detectedToken!.symbol,
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
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
  });

  final Token token;
  final int? chainId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                    token.name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
            Text(
              token.balance.toStringAsFixed(4),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
