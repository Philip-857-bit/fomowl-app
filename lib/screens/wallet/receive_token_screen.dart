import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../widgets/token_selector_modal.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';

import 'package:provider/provider.dart';

import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../models/chain.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/token_selector_card.dart';
import 'widgets/receive/receive_warning_banner.dart';
import 'widgets/receive/qr_code_card.dart';
import 'widgets/receive/address_display_card.dart';
import 'widgets/receive/receive_action_buttons.dart';

class ReceiveTokenScreen extends StatefulWidget {
  const ReceiveTokenScreen({super.key});

  @override
  State<ReceiveTokenScreen> createState() => _ReceiveTokenScreenState();
}

class _ReceiveTokenScreenState extends State<ReceiveTokenScreen> {
  Token? _selectedToken;
  ChainFamily? _lastFamily;
  String _walletAddress = '';
  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForFamily());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    final currentFamily = blockchain.activeFamily;
    // Re-initialise when the family changes OR when the selected token is
    // stale — i.e. it belongs to the previous network (happens because tokens
    // for the new family load asynchronously after the family switch).
    final tokenIsStale =
        _selectedToken != null &&
        _selectedToken!.networkKey != blockchain.activeNetworkKey;
    if (_lastFamily != currentFamily || tokenIsStale) {
      _lastFamily = currentFamily;
      _initForFamily();
    }
  }

  /// Resets the selected token to the native token of the active family and
  /// reloads the correct wallet address for that family.
  Future<void> _initForFamily() async {
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final family = blockchain.activeFamily;
    final activeNetworkKey = blockchain.activeNetworkKey;

    // Pick the native token for the active family from the loaded token list.
    final familyTokens = blockchain.tokens
        .where((t) => t.networkKey == activeNetworkKey)
        .toList();
    Token nativeToken;
    if (familyTokens.isNotEmpty) {
      nativeToken = familyTokens.firstWhere(
        (t) => t.contractAddress == null || t.contractAddress!.isEmpty,
        orElse: () => familyTokens.first,
      );
    } else {
      // Tokens haven't loaded yet for this family — use a lightweight
      // placeholder so we never fall back to ETH on a non-EVM network.
      // didChangeDependencies will re-init once the real tokens arrive.
      nativeToken = _placeholderNativeToken(family, activeNetworkKey);
    }

    final address = await _walletService.getWalletAddressForFamily(family);
    if (mounted) {
      setState(() {
        _selectedToken = nativeToken;
        _walletAddress = address ?? '';
      });
    }
  }

  /// Returns a minimal native-token stub for [family] so the UI never shows
  /// ETH while waiting for the real token list to load asynchronously.
  Token _placeholderNativeToken(ChainFamily family, String networkKey) {
    switch (family) {
      case ChainFamily.solana:
        return Token(
          symbol: 'SOL',
          name: 'Solana',
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          decimals: 9,
          networkKey: networkKey,
          tokenStandard: TokenStandard.native,
        );
      case ChainFamily.tron:
        return Token(
          symbol: 'TRX',
          name: 'Tron',
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          decimals: 6,
          networkKey: networkKey,
          tokenStandard: TokenStandard.native,
        );
      case ChainFamily.evm:
        return Token(
          symbol: 'ETH',
          name: 'Ethereum',
          balance: 0,
          valueUsd: 0,
          changePercent24h: 0,
          decimals: 18,
          networkKey: networkKey,
          tokenStandard: TokenStandard.native,
        );
    }
  }

  void _showTokenSelector() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final familyTokens = await _loadSelectableTokens(blockchain);
    if (!mounted) {
      return;
    }
    final result = await showDialog<Token>(
      context: context,
      builder: (context) => TokenSelectorDialog(
        tokens: familyTokens,
        chainId: blockchain.activeTokenStorageChainId,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedToken = result;
      });
    }
  }

  Future<List<Token>> _loadSelectableTokens(
    BlockchainService blockchain,
  ) async {
    final suggestedTokens = await _loadSuggestedTokens(blockchain);
    return _mergeSelectableTokens(blockchain, [
      [blockchain.activeNativeToken],
      blockchain.tokens,
      suggestedTokens,
      _customTokensForActiveNetwork(blockchain),
    ]);
  }

  Future<List<Token>> _loadSuggestedTokens(BlockchainService blockchain) async {
    try {
      return await blockchain.searchTokensFromBackend('', limit: 60);
    } catch (_) {
      return const [];
    }
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

  List<Token> _mergeSelectableTokens(
    BlockchainService blockchain,
    List<List<Token>> tokenGroups,
  ) {
    final byKey = <String, Token>{};
    for (final token in tokenGroups.expand((tokens) => tokens)) {
      if (!_tokenMatchesActiveNetwork(token, blockchain)) {
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

  @override
  Widget build(BuildContext context) {
    final blockchain = Provider.of<BlockchainService>(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SendHeader(
                title: l.receiveTokenTitle,
                onBack: () => Navigator.pop(context),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TokenSelectorCard(
                  token: _selectedToken,
                  onTap: _showTokenSelector,
                  blockchain: blockchain,
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReceiveWarningBanner(message: l.receiveExternalWarning),
              ),
              if (_walletAddress.isEmpty &&
                  blockchain.activeFamily != ChainFamily.evm) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ReceiveWarningBanner(
                    message:
                        'This wallet was imported via private key and does not have a ${blockchain.activeFamily == ChainFamily.solana ? 'Solana' : 'Tron'} address. '
                        'Create a new wallet from a seed phrase to receive on this network.',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.warning,
                    borderColor: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 32),

              QrCodeCard(data: _walletAddress),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AddressDisplayCard(
                  value: _walletAddress,
                  isInterTransfer: false,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: _walletAddress));
                    ToastUtils.showSuccess(l.addressCopied);
                  },
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ReceiveActionButtons(
                  onShare: () => Navigator.pop(context),
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: _walletAddress));
                    ToastUtils.showSuccess(l.addressCopied);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
